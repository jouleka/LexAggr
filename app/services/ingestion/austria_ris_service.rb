require "nokogiri"

module Ingestion
  class AustriaRisService < BaseService
    BASE_URL = "https://data.bka.gv.at".freeze

    AUSTRIAN_TYPE_MAP = {
      "BG" => "act",
      "BVG" => "act",
      "V" => "regulation",
      "E" => "decision",
      "K" => "directive",
      "Vertrag" => "other"
    }.freeze

    def fetch_document_list(since:)
      since_date = since.to_date
      results = []
      page = 1

      loop do
        response = ris_client.get("/ris/api/v2.6/Bundesrecht", {
          Applikation: "BrKons",
          DatumVon: since_date.strftime("%Y-%m-%d"),
          Seitennummer: page
        })

        break unless response.status == 200

        doc = Nokogiri::XML(response.body)
        entries = doc.xpath("//OgdDocumentReference")
        break if entries.empty?

        entries.each do |entry|
          parsed = parse_entry(entry)
          results << parsed if parsed
        end

        hits = doc.at_xpath("//Hits/Treffer")&.text.to_i
        page_size = doc.at_xpath("//Hits/Seitengroesse")&.text.to_i
        break if page_size.zero? || (page * page_size) >= hits

        page += 1
      end

      results
    rescue Faraday::Error => e
      Rails.logger.error("[AustriaRisService] Fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      doc_number = ref[:document_number]

      response = ris_client.get("/ris/api/v2.6/Bundesrecht", {
        Applikation: "BrKons",
        Dokumentnummer: doc_number
      })
      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        source_identifier: doc_number,
        raw_xml: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[AustriaRisService] Document fetch failed for #{ref[:document_number]}: #{e.message}")
      {}
    end

    def map_document_type(doc_type)
      AUSTRIAN_TYPE_MAP.fetch(doc_type, "other")
    end

    private

    def ris_client
      @ris_client ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [ 429, 500, 502, 503, 504 ]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.headers["Accept"] = "application/xml"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_entry(entry)
      doc_number = entry.at_xpath(".//Dokumentnummer")&.text
      title = entry.at_xpath(".//Kurztitel")&.text
      return nil if doc_number.blank? || title.blank?

      doc_type = entry.at_xpath(".//Dokumenttyp")&.text
      article_paragraph = entry.at_xpath(".//ArtikelParagraphAnlworting")&.text

      {
        source_identifier: doc_number,
        frbr_uri: "/eli/at/bgbl/#{doc_number}",
        title: title,
        legislation_type: map_document_type(doc_type),
        article_paragraph: article_paragraph,
        document_number: doc_number
      }
    end
  end
end
