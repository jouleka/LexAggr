module Ingestion
  class SwitzerlandFedlexService < BaseService
    SPARQL_ENDPOINT = "https://fedlex.data.admin.ch/sparqlendpoint".freeze
    JOLUX_PREFIX = "PREFIX jolux: <http://data.legilux.public.lu/resource/ontology/jolux#>".freeze

    def fetch_document_list(since:)
      query = build_sparql_query(since: since, limit: 100)
      response = fedlex_client.post(
        "/sparqlendpoint",
        URI.encode_www_form(query: query),
        { "Accept" => "application/sparql-results+json", "Content-Type" => "application/x-www-form-urlencoded" }
      )

      return [] unless response.status == 200
      parse_sparql_results(response.body)
    rescue Faraday::Error => e
      Rails.logger.error("[SwitzerlandFedlexService] SPARQL query failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      uri = ref[:uri]
      return {} if uri.blank?

      path = URI(uri).path
      response = fedlex_client.get(path, nil, {
        "Accept" => "application/xml",
        "Accept-Language" => "en"
      })

      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        uri: uri,
        raw_xml: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[SwitzerlandFedlexService] Document fetch failed for #{uri}: #{e.message}")
      {}
    end

    private

    def build_sparql_query(since:, limit: 100)
      since_date = since.to_date.iso8601
      <<~SPARQL
        #{JOLUX_PREFIX}
        PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
        SELECT DISTINCT ?uri ?title ?date
        WHERE {
          ?uri a jolux:Act .
          ?uri jolux:dateDocument ?date .
          ?uri jolux:titleTreatment ?titleNode .
          ?titleNode jolux:language <http://publications.europa.eu/resource/authority/language/ENG> .
          ?titleNode jolux:text ?title .
          FILTER(?date >= "#{since_date}"^^xsd:date)
        }
        ORDER BY DESC(?date)
        LIMIT #{limit}
      SPARQL
    end

    def fedlex_client
      @fedlex_client ||= Faraday.new(url: "https://fedlex.data.admin.ch") do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [ 429, 500, 502, 503, 504 ]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_sparql_results(json_body)
      data = JSON.parse(json_body)
      bindings = data.dig("results", "bindings") || []

      bindings.map do |binding|
        uri = binding.dig("uri", "value")
        {
          uri: uri,
          title: binding.dig("title", "value"),
          date: binding.dig("date", "value"),
          legislation_type: "act",
          frbr_uri: "/eli/ch/#{uri_to_eli_path(uri)}"
        }
      end
    end

    def uri_to_eli_path(uri)
      return "" if uri.blank?
      URI(uri).path.sub(%r{^/eli/}, "")
    end
  end
end
