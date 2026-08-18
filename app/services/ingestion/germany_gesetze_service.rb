require "nokogiri"
require "zip"

module Ingestion
  class GermanyGesetzeService < BaseService
    TOC_URL = "https://www.gesetze-im-internet.de/gii-toc.xml".freeze

    def fetch_document_list(since:)
      response = gesetze_client.get("/gii-toc.xml")
      return [] unless response.status == 200

      parse_toc(response.body)
    rescue Faraday::Error => e
      Rails.logger.error("[GermanyGesetzeService] TOC fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      zip_url = ref[:zip_url]
      return {} if zip_url.blank?

      response = gesetze_client.get(URI(zip_url).path)
      return {} unless response.status == 200

      xml_content = extract_xml_from_zip(response.body)
      return {} if xml_content.nil? || xml_content.empty?

      {
        source_identifier: ref[:source_identifier],
        raw_xml: xml_content,
        content_hash: compute_content_hash(xml_content)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[GermanyGesetzeService] Document fetch failed for #{ref[:source_identifier]}: #{e.message}")
      {}
    rescue Zip::Error => e
      Rails.logger.error("[GermanyGesetzeService] ZIP extraction failed for #{ref[:source_identifier]}: #{e.message}")
      {}
    end

    private

    def gesetze_client
      @gesetze_client ||= Faraday.new(url: "https://www.gesetze-im-internet.de") do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [ 429, 500, 502, 503, 504 ]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_toc(xml_body)
      doc = Nokogiri::XML(xml_body)
      items = []

      doc.xpath("//item").each do |item_node|
        title = item_node.at_xpath("title")&.text
        link = item_node.at_xpath("link")&.text
        next if title.blank? || link.blank?

        # Extract abbreviation from link path for identifier
        abbr = link.match(%r{/([^/]+)/xml\.zip\z})&.captures&.first || title
        items << {
          source_identifier: abbr,
          title: title,
          zip_url: link,
          legislation_type: "act",
          frbr_uri: "/eli/de/#{abbr}"
        }
      end

      items
    end

    def extract_xml_from_zip(zip_data)
      io = StringIO.new(zip_data)
      Zip::InputStream.open(io) do |zip|
        while (entry = zip.get_next_entry)
          if entry.name.end_with?(".xml")
            return entry.get_input_stream.read
          end
        end
      end
      nil
    end
  end
end
