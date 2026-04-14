module Ingestion
  class SwedenRiksdagenService < BaseService
    BASE_URL = "https://data.riksdagen.se".freeze

    SWEDISH_TYPE_MAP = {
      "sfs" => "act",
      "prop" => "other",
      "mot" => "other",
      "bet" => "decision",
      "rskr" => "directive",
      "ds" => "regulation",
      "sou" => "other"
    }.freeze

    def fetch_document_list(since:)
      since_date = since.to_date
      start_year = since_date.year
      end_year = Date.current.year

      results = []

      (start_year..end_year).each do |year|
        response = riksdagen_client.get("/dokumentlista/", {
          sok: "",
          doktyp: "sfs",
          rm: year.to_s,
          utformat: "json",
          maxtrad: 100
        })

        next unless response.status == 200

        data = JSON.parse(response.body)
        documents = data.dig("dokumentlista", "dokument") || []

        documents.each do |doc|
          doc_date = Date.parse(doc["datum"]) rescue nil
          next if doc_date && doc_date < since_date

          results << {
            source_identifier: doc["dok_id"],
            frbr_uri: "/eli/se/sfs/#{doc['dok_id']}",
            title: doc["titel"],
            legislation_type: map_document_type(doc["typ"]),
            year: year,
            date: doc["datum"],
            rm: doc["rm"]
          }
        end
      end

      results
    rescue Faraday::Error => e
      Rails.logger.error("[SwedenRiksdagenService] Fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      dok_id = ref[:dok_id]

      response = riksdagen_client.get("/dokument/#{dok_id}.json")
      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        source_identifier: dok_id,
        raw_xml: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[SwedenRiksdagenService] Document fetch failed for #{ref[:dok_id]}: #{e.message}")
      {}
    end

    def map_document_type(dok_type)
      SWEDISH_TYPE_MAP.fetch(dok_type.to_s.downcase, "other")
    end

    private

    def riksdagen_client
      @riksdagen_client ||= http_client(base_url: BASE_URL)
    end
  end
end
