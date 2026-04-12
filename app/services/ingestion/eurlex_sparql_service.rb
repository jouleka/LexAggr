module Ingestion
  class EurlexSparqlService < BaseService
    SPARQL_ENDPOINT = "https://publications.europa.eu/webapi/rdf/sparql".freeze
    CDM_PREFIX = "PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>".freeze
    CELLAR_XML_BASE = "https://eur-lex.europa.eu/legal-content/EN/TXT/XML/?uri=CELEX:".freeze

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
      response = http_client.get(SPARQL_ENDPOINT, { query: query }, {
        "Accept" => "application/sparql-results+json"
      })

      return [] unless response.status == 200
      parse_sparql_results(response.body)
    rescue Faraday::Error => e
      Rails.logger.error("[EurlexSparqlService] SPARQL query failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      celex = ref[:celex_number]
      url = "#{CELLAR_XML_BASE}#{celex}"
      response = http_client.get(url)

      return {} unless response.status == 200

      {
        celex_number: celex,
        raw_xml: response.body,
        content_hash: compute_content_hash(response.body)
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
          ?work cdm:work_has_expression ?expr .
          ?expr cdm:expression_uses_language
                <http://publications.europa.eu/resource/authority/language/ENG> .
          ?expr cdm:expression_title ?title .
          FILTER(?date >= "#{since.to_date.iso8601}"^^xsd:date)
        }
        ORDER BY DESC(?date)
        LIMIT #{limit}
      SPARQL
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

    def resource_type_to_legislation_type(code)
      RESOURCE_TYPE_MAP.fetch(code, "other")
    end
  end
end
