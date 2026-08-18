module Ingestion
  class FinlexService < BaseService
    BASE_URL = "https://opendata.finlex.fi".freeze
    API_PATH = "/finlex/avoindata/v1".freeze

    def fetch_document_list(since:)
      since_date = since.to_date
      start_year = since_date.year
      end_year = Date.today.year

      results = []

      (start_year..end_year).each do |year|
        page = 1
        loop do
          response = finlex_client.get("#{API_PATH}/akn/fi/act/statute/list", {
            format: "json",
            page: page,
            limit: 100,
            startYear: year,
            endYear: year
          })

          break unless response.status == 200

          entries = JSON.parse(response.body)
          break if entries.empty?

          entries.each do |entry|
            parsed = parse_akn_uri(entry["akn_uri"])
            next unless parsed

            results << parsed.merge(
              title: "Finnish Statute #{parsed[:number]}/#{parsed[:year]}",
              legislation_type: "act",
              status: entry["status"]
            )
          end

          # If we got fewer than 100 results, no more pages
          break if entries.length < 100

          page += 1
        end
      end

      results
    rescue Faraday::Error => e
      Rails.logger.error("[FinlexService] List fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      year = ref[:year]
      number = ref[:number]
      source_id = ref[:source_identifier]

      response = finlex_client.get("#{API_PATH}/akn/fi/act/statute/#{year}/#{number}/fin@")

      return {} unless response.status == 200

      {
        source_identifier: source_id,
        raw_xml: response.body,
        content_hash: compute_content_hash(response.body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[FinlexService] Document fetch failed for #{ref[:source_identifier]}: #{e.message}")
      {}
    end

    private

    def finlex_client
      @finlex_client ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [ 429, 500, 502, 503, 504 ]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_akn_uri(akn_uri)
      return nil unless akn_uri

      match = akn_uri.match(%r{/akn/fi/act/statute/(\d{4})/(\d+)})
      return nil unless match

      year = match[1]
      number = match[2]

      {
        year: year,
        number: number,
        source_identifier: "fi/act/statute/#{year}/#{number}",
        frbr_uri: "/akn/fi/act/statute/#{year}/#{number}"
      }
    end
  end
end
