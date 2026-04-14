require "nokogiri"

module Ingestion
  class NorwayLovdataService < BaseService
    BASE_URL = "https://api.lovdata.no".freeze

    NORWEGIAN_TYPE_MAP = {
      "lov" => "act",
      "forskrift" => "regulation",
      "vedtak" => "decision",
      "instruks" => "directive",
      "resolusjon" => "decision"
    }.freeze

    NORWEGIAN_STATUS_MAP = {
      "gjeldende" => "in_force",
      "opphevet" => "repealed"
    }.freeze

    def fetch_document_list(since:)
      since_date = since.to_date

      response = lovdata_client.get("/api/v1/laws", {
        modified_since: since_date.iso8601
      })

      return [] unless response.status == 200

      doc = Nokogiri::XML(response.body)
      results = []

      doc.xpath("//law").each do |law_node|
        parsed = parse_law_entry(law_node)
        results << parsed if parsed
      end

      results
    rescue Faraday::Error => e
      Rails.logger.error("[NorwayLovdataService] Fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      law_id = ref[:id]

      response = lovdata_client.get("/api/v1/laws/#{law_id}")
      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        source_identifier: law_id,
        raw_xml: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[NorwayLovdataService] Document fetch failed for #{ref[:id]}: #{e.message}")
      {}
    end

    def map_document_type(norwegian_type)
      NORWEGIAN_TYPE_MAP.fetch(norwegian_type.to_s.downcase, "other")
    end

    def map_status(status)
      NORWEGIAN_STATUS_MAP.fetch(status.to_s.downcase, "in_force")
    end

    private

    def lovdata_client
      @lovdata_client ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [429, 500, 502, 503, 504]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.headers["Accept"] = "application/xml"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_law_entry(law_node)
      id = law_node.at_xpath("id")&.text
      title = law_node.at_xpath("title")&.text
      return nil if id.blank? || title.blank?

      law_type = law_node.at_xpath("type")&.text
      status = law_node.at_xpath("status")&.text
      date = law_node.at_xpath("date")&.text

      {
        source_identifier: id,
        frbr_uri: "/eli/no/lov/#{id}",
        title: title,
        legislation_type: map_document_type(law_type),
        status: map_status(status),
        date: date,
        id: id
      }
    end
  end
end
