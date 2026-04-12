module Ingestion
  class EurlexSparqlService < BaseService
    SPARQL_ENDPOINT = "https://publications.europa.eu/webapi/rdf/sparql".freeze
    CDM_PREFIX = "PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>".freeze

    def fetch_document_list(since:)
      []
    end

    def fetch_document(ref:)
      {}
    end
  end
end
