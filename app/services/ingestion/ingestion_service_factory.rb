module Ingestion
  class IngestionServiceFactory
    STRATEGIES = {
      "eu" => "Ingestion::EurlexSparqlService"
    }.freeze

    def self.for(jurisdiction_code)
      class_name = STRATEGIES.fetch(jurisdiction_code)
      class_name.constantize.new
    end

    def self.registered?(jurisdiction_code)
      STRATEGIES.key?(jurisdiction_code)
    end

    def self.registered_codes
      STRATEGIES.keys
    end
  end
end
