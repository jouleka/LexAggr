module Ingestion
  class EurlexSparqlService < BaseService
    SPARQL_ENDPOINT = "https://publications.europa.eu/webapi/rdf/sparql".freeze
    CDM_PREFIX = "PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>".freeze
    CELLAR_BASE = "https://publications.europa.eu/resource/celex/".freeze

    RESOURCE_TYPE_MAP = {
      "REG" => "regulation",
      "DIR" => "directive",
      "DEC" => "decision",
      "DIRDEL" => "delegated_directive",
      "REGDEL" => "delegated_regulation",
      "REGIMPL" => "implementing_regulation"
    }.freeze

    def fetch_document_list(since:)
      query = build_sparql_query(since: since, limit: 100)
      response = sparql_client.post(
        "/webapi/rdf/sparql",
        URI.encode_www_form(query: query),
        { "Accept" => "application/sparql-results+json", "Content-Type" => "application/x-www-form-urlencoded" }
      )

      return [] unless response.status == 200
      parse_sparql_results(response.body)
    rescue Faraday::Error => e
      Rails.logger.error("[EurlexSparqlService] SPARQL query failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      celex = ref[:celex_number]
      cellar_uri = ref[:cellar_uri]

      # Use CELLAR content negotiation with redirect following
      # CELLAR returns 303 -> specific manifestation URI -> 200 with content
      path = cellar_uri ? URI(cellar_uri).path : "/resource/celex/#{celex}"
      body = fetch_with_redirect(path, accept: "application/xhtml+xml")
      body ||= fetch_with_redirect(path, accept: "application/xml")

      return {} if body.nil? || body.empty?

      {
        celex_number: celex,
        raw_xml: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[EurlexSparqlService] Document fetch failed for #{celex}: #{e.message}")
      {}
    end

    private

    def build_sparql_query(since:, limit: 100)
      <<~SPARQL
        #{CDM_PREFIX}
        PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

        SELECT DISTINCT ?celex ?title ?date ?work ?restype
        WHERE {
          ?work cdm:work_has_resource-type ?restype .
          FILTER(?restype IN (
            <http://publications.europa.eu/resource/authority/resource-type/REG>,
            <http://publications.europa.eu/resource/authority/resource-type/DIR>,
            <http://publications.europa.eu/resource/authority/resource-type/DEC>
          ))
          ?work cdm:resource_legal_id_celex ?celex .
          ?work cdm:work_date_document ?date .
          ?expr cdm:expression_belongs_to_work ?work .
          ?expr cdm:expression_uses_language
                <http://publications.europa.eu/resource/authority/language/ENG> .
          ?expr cdm:expression_title ?title .
          FILTER(?date >= "#{since.to_date.iso8601}"^^xsd:date)
        }
        ORDER BY DESC(?date)
        LIMIT #{limit}
      SPARQL
    end

    def sparql_client
      @sparql_client ||= Faraday.new(url: "https://publications.europa.eu") do |f|
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
        restype_uri = binding.dig("restype", "value") || ""
        restype_code = restype_uri.split("/").last

        {
          celex_number: binding.dig("celex", "value"),
          title: binding.dig("title", "value"),
          date: binding.dig("date", "value"),
          cellar_uri: binding.dig("work", "value"),
          legislation_type: resource_type_to_legislation_type(restype_code),
          frbr_uri: "/eli/celex/#{binding.dig('celex', 'value')}"
        }
      end
    end

    def fetch_with_redirect(path, accept:, max_redirects: 3)
      current_path = path
      max_redirects.times do
        response = sparql_client.get(current_path, nil, {
          "Accept" => accept,
          "Accept-Language" => "en"
        })

        case response.status
        when 200
          return response.body if response.body.present?
        when 301, 302, 303
          location = response.headers["location"]
          return nil unless location
          current_path = URI(location).path
        else
          return nil
        end
      end
      nil
    end

    def resource_type_to_legislation_type(code)
      RESOURCE_TYPE_MAP.fetch(code, "other")
    end
  end
end
