module Ingestion
  class BaseService
    def fetch_document_list(since:)
      raise NotImplementedError, "#{self.class}#fetch_document_list not implemented"
    end

    def fetch_document(ref:)
      raise NotImplementedError, "#{self.class}#fetch_document not implemented"
    end

    private

    def http_client(base_url: nil)
      Faraday.new(url: base_url) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [429, 500, 502, 503, 504]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.adapter Faraday.default_adapter
      end
    end

    def compute_content_hash(content)
      Digest::SHA256.hexdigest(content.to_s)
    end
  end
end
