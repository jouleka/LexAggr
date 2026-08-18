require "nokogiri"

module Ingestion
  class FranceDilaService < BaseService
    BULK_BASE_URL = "https://echanges.dila.gouv.fr/OPENDATA/LEGI/".freeze
    LEGIFRANCE_BASE_URL = "https://www.legifrance.gouv.fr".freeze

    TITLE_TYPE_PATTERNS = [
      { pattern: /\bLOI\b/i, type: "act" },
      { pattern: /\bOrdonnance\b/i, type: "regulation" },
      { pattern: /\bD[eé]cret\b/i, type: "regulation" },
      { pattern: /\bArr[eê]t[eé]\b/i, type: "directive" },
      { pattern: /\bD[eé]cision\b/i, type: "decision" }
    ].freeze

    def fetch_document_list(since:)
      response = dila_client.get("/OPENDATA/LEGI/")
      return [] unless response.status == 200

      parse_directory_listing(response.body, since: since.to_date)
    rescue Faraday::Error => e
      Rails.logger.error("[FranceDilaService] Directory fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      identifier = ref[:source_identifier]
      return {} if identifier.blank?

      response = legifrance_client.get("/jorf/id/#{identifier}")
      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        source_identifier: identifier,
        raw_html: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[FranceDilaService] Document fetch failed for #{identifier}: #{e.message}")
      {}
    end

    def detect_legislation_type(title)
      TITLE_TYPE_PATTERNS.each do |entry|
        return entry[:type] if title.match?(entry[:pattern])
      end
      "other"
    end

    private

    def dila_client
      @dila_client ||= Faraday.new(url: "https://echanges.dila.gouv.fr") do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [ 429, 500, 502, 503, 504 ]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.adapter Faraday.default_adapter
      end
    end

    def legifrance_client
      @legifrance_client ||= Faraday.new(url: LEGIFRANCE_BASE_URL) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [ 429, 500, 502, 503, 504 ]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_directory_listing(html_body, since:)
      doc = Nokogiri::HTML(html_body)
      entries = []

      doc.css("a").each do |link|
        href = link["href"]
        next unless href&.match?(/\ALEGI_\d{8}/)

        date_str = href.match(/LEGI_(\d{8})/)[1]
        file_date = Date.strptime(date_str, "%Y%m%d")
        next if file_date < since

        entries << {
          source_identifier: href.sub(/\.tar\.gz\z/, ""),
          title: href,
          date: file_date.iso8601,
          legislation_type: "other",
          frbr_uri: "/eli/fr/legi/#{date_str}"
        }
      end

      entries.sort_by { |e| e[:date] }.reverse
    end
  end
end
