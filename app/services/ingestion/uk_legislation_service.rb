module Ingestion
  class UkLegislationService < BaseService
    BASE_URL = "https://www.legislation.gov.uk".freeze

    DOCUMENT_TYPE_MAP = {
      "UnitedKingdomPublicGeneralAct" => "act",
      "UnitedKingdomLocalAct" => "act",
      "UnitedKingdomPrivateOrPersonalAct" => "act",
      "ScottishAct" => "act",
      "WelshParliamentAct" => "act",
      "NorthernIrelandAct" => "act",
      "UnitedKingdomStatutoryInstrument" => "regulation",
      "ScottishStatutoryInstrument" => "regulation",
      "WelshStatutoryInstrument" => "regulation",
      "NorthernIrelandStatutoryRule" => "regulation",
      "UnitedKingdomMinisterialOrder" => "decision",
      "UnitedKingdomMinisterialDirection" => "decision"
    }.freeze

    ATOM_NS = {
      "atom" => "http://www.w3.org/2005/Atom",
      "pbl" => "http://www.legislation.gov.uk/namespaces/publication-log",
      "ukm" => "http://www.legislation.gov.uk/namespaces/metadata",
      "dc" => "http://purl.org/dc/elements/1.1/"
    }.freeze

    def fetch_document_list(since:)
      response = uk_client.get("/update/data.feed", {
        event: "published",
        new: "true",
        format: "xml"
      })

      return [] unless response.status == 200
      parse_publication_log(response.body, since: since)
    rescue Faraday::Error => e
      Rails.logger.error("[UkLegislationService] Feed fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      source_id = ref[:source_identifier]
      response = uk_client.get("/#{source_id}/data.akn")

      return {} unless response.status == 200

      {
        source_identifier: source_id,
        raw_xml: response.body,
        content_hash: compute_content_hash(response.body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[UkLegislationService] Document fetch failed for #{ref[:source_identifier]}: #{e.message}")
      {}
    end

    private

    def uk_client
      @uk_client ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [429, 500, 502, 503, 504]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_publication_log(xml_body, since:)
      doc = Nokogiri::XML(xml_body)
      entries = doc.xpath("//atom:entry", ATOM_NS)

      since_date = since.to_date

      entries.filter_map do |entry|
        updated_text = entry.at_xpath("atom:updated", ATOM_NS)&.text
        next unless updated_text

        updated_date = Date.parse(updated_text)
        next if updated_date < since_date

        identifier = entry.at_xpath("dc:identifier", ATOM_NS)&.text
        next unless identifier

        source_id = identifier.sub("http://www.legislation.gov.uk/id/", "")
        title = entry.at_xpath("atom:title", ATOM_NS)&.text
        doc_type = entry.at_xpath("ukm:DocumentMainType/@Value", ATOM_NS)&.text

        {
          source_identifier: source_id,
          frbr_uri: "/#{source_id}",
          title: title,
          updated: updated_text,
          legislation_type: document_type_to_legislation_type(doc_type)
        }
      end
    end

    def document_type_to_legislation_type(doc_type)
      DOCUMENT_TYPE_MAP.fetch(doc_type, "other")
    end
  end
end
