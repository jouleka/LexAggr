module Ingestion
  class ItalyNormattivaService < BaseService
    BASE_URL = "https://api.normattiva.it/t/normattiva.api/".freeze

    ITALIAN_TYPE_MAP = {
      "LEGGE" => "act",
      "DECRETO LEGISLATIVO" => "regulation",
      "DECRETO LEGGE" => "regulation",
      "DECRETO DEL PRESIDENTE DELLA REPUBBLICA" => "regulation",
      "DECRETO MINISTERIALE" => "directive",
      "DIRETTIVA" => "directive",
      "DECISIONE" => "decision"
    }.freeze

    STATUS_MAP = {
      "vigente" => "in_force",
      "abrogato" => "repealed"
    }.freeze

    def fetch_document_list(since:)
      since_date = since.to_date.iso8601
      response = normattiva_client.get(
        "bff-opendata/v1/api/v1/ricerca/predefinita",
        { dataInizio: since_date, dataFine: Date.current.iso8601 }
      )

      return [] unless response.status == 200
      parse_search_results(response.body)
    rescue Faraday::Error => e
      Rails.logger.error("[ItalyNormattivaService] Search failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      act_id = ref[:source_identifier]
      return {} if act_id.blank?

      response = normattiva_client.get("bff-opendata/v1/api/v1/atti/#{act_id}/testo")
      return {} unless response.status == 200

      body = response.body
      return {} if body.nil? || body.empty?

      {
        source_identifier: act_id,
        raw_html: body,
        content_hash: compute_content_hash(body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[ItalyNormattivaService] Document fetch failed for #{act_id}: #{e.message}")
      {}
    end

    def italian_type_to_legislation_type(italian_type)
      ITALIAN_TYPE_MAP.fetch(italian_type, "other")
    end

    private

    def normattiva_client
      @normattiva_client ||= http_client(base_url: BASE_URL)
    end

    def parse_search_results(json_body)
      data = JSON.parse(json_body)
      items = data["data"] || []

      items.map do |item|
        {
          source_identifier: item["id"],
          title: item["titolo"],
          date: item["dataAtto"],
          legislation_type: italian_type_to_legislation_type(item["tipoAtto"]),
          status: map_status(item["stato"]),
          frbr_uri: "/eli/it/#{item['tipoAtto']&.downcase&.gsub(/\s+/, '-')}/#{item['dataAtto']}/#{item['numAtto']}"
        }
      end
    end

    def map_status(stato)
      STATUS_MAP.fetch(stato, "in_force")
    end
  end
end
