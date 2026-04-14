module Ingestion
  class PolandEliService < BaseService
    BASE_URL = "https://api.sejm.gov.pl".freeze

    POLISH_TYPE_MAP = {
      "Ustawa" => "act",
      "Rozporzadzenie" => "regulation",
      "Obwieszczenie" => "decision",
      "Postanowienie" => "decision"
    }.freeze

    STATUS_MAP = {
      "IN_FORCE" => "in_force",
      "NOT_IN_FORCE" => "repealed"
    }.freeze

    def fetch_document_list(since:)
      since_time = since.to_time
      results = []

      (since_time.year..Date.current.year).each do |year|
        response = poland_client.get("/eli/acts/DU/#{year}")
        next unless response.status == 200

        items = JSON.parse(response.body)["items"] || []
        items.each do |item|
          change_time = Time.parse(item["changeDate"])
          next if change_time < since_time

          results << {
            source_identifier: item["ELI"],
            frbr_uri: "/eli/pl/#{item['publisher']}/#{item['year']}/#{item['pos']}",
            title: item["title"],
            legislation_type: polish_type_to_legislation_type(item["type"]),
            year: item["year"],
            status: map_status(item["inForce"]),
            publisher: item["publisher"],
            pos: item["pos"]
          }
        end
      end

      results
    rescue Faraday::Error => e
      Rails.logger.error("[PolandEliService] Fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      publisher = ref[:publisher]
      year = ref[:year]
      pos = ref[:pos]

      response = poland_client.get("/eli/acts/#{publisher}/#{year}/#{pos}/text.html")
      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        source_identifier: "#{publisher}/#{year}/#{pos}",
        raw_xml: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[PolandEliService] Document fetch failed: #{e.message}")
      {}
    end

    def polish_type_to_legislation_type(polish_type)
      POLISH_TYPE_MAP.fetch(polish_type, "other")
    end

    private

    def poland_client
      @poland_client ||= http_client(base_url: BASE_URL)
    end

    def map_status(in_force_value)
      STATUS_MAP.fetch(in_force_value, "in_force")
    end
  end
end
