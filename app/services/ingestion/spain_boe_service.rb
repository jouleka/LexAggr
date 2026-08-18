require "nokogiri"

module Ingestion
  class SpainBoeService < BaseService
    BASE_URL = "https://www.boe.es/datosabiertos/api/".freeze

    TITLE_TYPE_PATTERNS = [
      { pattern: /\bLey\b/i, type: "act" },
      { pattern: /\bReal Decreto\b/i, type: "regulation" },
      { pattern: /\bOrden\b/i, type: "directive" },
      { pattern: /\bResolucion\b/i, type: "decision" }
    ].freeze

    def fetch_document_list(since:)
      results = []
      since_date = since.to_date
      current_date = Date.current

      (since_date..current_date).each do |date|
        formatted_date = date.strftime("%Y%m%d")
        response = boe_client.get("boe/sumario/#{formatted_date}")
        next unless response.status == 200

        results.concat(parse_sumario(response.body))
      end

      results
    rescue Faraday::Error => e
      Rails.logger.error("[SpainBoeService] Fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      identifier = ref[:source_identifier]
      response = boe_client.get("legislacion-consolidada/id/#{identifier}/texto")
      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        source_identifier: identifier,
        raw_xml: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[SpainBoeService] Document fetch failed for #{ref[:source_identifier]}: #{e.message}")
      {}
    end

    def detect_legislation_type(title)
      TITLE_TYPE_PATTERNS.each do |entry|
        return entry[:type] if title.match?(entry[:pattern])
      end
      "other"
    end

    private

    def boe_client
      @boe_client ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [ 429, 500, 502, 503, 504 ]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.headers["Accept"] = "application/xml"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_sumario(xml_body)
      doc = Nokogiri::XML(xml_body)
      items = []

      doc.xpath("//item").each do |item_node|
        titulo = item_node.at_xpath("titulo")&.text
        identificador = item_node.at_xpath("identificador")&.text
        next if titulo.blank? || identificador.blank?

        items << {
          source_identifier: identificador,
          title: titulo,
          legislation_type: detect_legislation_type(titulo),
          frbr_uri: "/eli/es/boe/#{identificador}"
        }
      end

      items
    end
  end
end
