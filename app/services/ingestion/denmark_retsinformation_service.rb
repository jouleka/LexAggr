module Ingestion
  class DenmarkRetsinformationService < BaseService
    BASE_URL = "https://api.retsinformation.dk".freeze
    THROTTLE_SECONDS = 10

    DANISH_TYPE_MAP = {
      "LOV" => "act",
      "LBK" => "act",
      "BEK" => "regulation",
      "CIR" => "directive",
      "VEJ" => "directive",
      "AFG" => "decision",
      "SKR" => "other"
    }.freeze

    DANISH_STATUS_MAP = {
      "gaeldende" => "in_force",
      "historisk" => "repealed"
    }.freeze

    def fetch_document_list(since:)
      since_date = since.to_date
      results = []

      response = retsinformation_client.get("/api/v1/documents", {
        from: since_date.iso8601,
        limit: 100
      })

      return [] unless response.status == 200

      entries = JSON.parse(response.body)
      return [] unless entries.is_a?(Array)

      entries.each do |entry|
        results << {
          source_identifier: entry["id"].to_s,
          frbr_uri: "/eli/dk/ret/#{entry['id']}",
          title: entry["title"],
          legislation_type: map_document_type(entry["documentType"]),
          status: map_status(entry["status"]),
          date: entry["publicationDate"],
          document_number: entry["documentNumber"]
        }
      end

      results
    rescue Faraday::Error => e
      Rails.logger.error("[DenmarkRetsinformationService] Fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      doc_id = ref[:id]

      throttle!

      response = retsinformation_client.get("/api/v1/documents/#{doc_id}")
      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        source_identifier: doc_id.to_s,
        raw_xml: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[DenmarkRetsinformationService] Document fetch failed for #{ref[:id]}: #{e.message}")
      {}
    end

    def map_document_type(doc_type)
      DANISH_TYPE_MAP.fetch(doc_type.to_s, "other")
    end

    def map_status(status)
      DANISH_STATUS_MAP.fetch(status.to_s, "in_force")
    end

    private

    def retsinformation_client
      @retsinformation_client ||= http_client(base_url: BASE_URL)
    end

    def throttle!
      sleep(THROTTLE_SECONDS)
    end
  end
end
