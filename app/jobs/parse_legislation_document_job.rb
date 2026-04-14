class ParseLegislationDocumentJob < ApplicationJob
  queue_as :ingestion

  def perform(jurisdiction_code, doc_ref_json)
    doc_ref = JSON.parse(doc_ref_json, symbolize_names: true)
    jurisdiction = Jurisdiction.find_by!(code: jurisdiction_code)
    service = Ingestion::IngestionServiceFactory.for(jurisdiction_code)

    result = service.fetch_document(ref: doc_ref)

    legislation = Legislation.find_or_initialize_by(frbr_uri: doc_ref[:frbr_uri])
    legislation.assign_attributes(
      jurisdiction: jurisdiction,
      title: doc_ref[:title],
      legislation_type: doc_ref[:legislation_type],
      celex_number: result[:celex_number] || doc_ref[:celex_number],
      year: doc_ref[:year] || extract_year(doc_ref[:date]),
      status: doc_ref[:status] || "in_force",
      source_identifier: doc_ref[:source_identifier] || doc_ref[:celex_number]
    )

    new_hash = result[:content_hash] || compute_metadata_hash(doc_ref)
    return if legislation.persisted? && legislation.content_hash == new_hash

    legislation.content_hash = new_hash
    legislation.save!

    version = legislation.legislation_versions.find_or_initialize_by(
      version_uri: "#{doc_ref[:frbr_uri]}/en"
    )
    version.assign_attributes(
      language: "en",
      valid_from: parse_date(doc_ref[:date]),
      version_type: "original"
    )
    version.save!

    # Store raw content in the separate content table (if available)
    if result[:raw_xml].present?
      content = version.content || version.build_content
      content.update!(raw_xml: result[:raw_xml])
      build_document_tree(version, result[:raw_xml])
    end
  rescue StandardError => e
    Rails.logger.error("[ParseLegislationDocumentJob] Failed for #{doc_ref}: #{e.message}")
    raise
  end

  private

  def compute_metadata_hash(doc_ref)
    Digest::SHA256.hexdigest("#{doc_ref[:frbr_uri]}:#{doc_ref[:title]}:#{doc_ref[:date]}")
  end

  def extract_year(date_string)
    return nil unless date_string
    Date.parse(date_string).year
  rescue Date::Error
    nil
  end

  def parse_date(date_string)
    return nil unless date_string
    Date.parse(date_string)
  rescue Date::Error
    nil
  end

  def build_document_tree(version, xml)
    parser = detect_parser(xml)
    return unless parser

    nodes = parser.extract_body_hierarchy
    version.document_nodes.destroy_all
    persist_nodes(version, nodes, nil, 0)
  end

  def detect_parser(xml)
    if xml.include?("akomaNtoso") || xml.include?("docs.oasis-open.org/legaldocml")
      Parsers::AknParser.new(xml)
    elsif xml.include?("CONSLEG.ACT") || xml.include?("ENACTING.TERMS")
      Parsers::FormexParser.new(xml)
    end
  end

  def persist_nodes(version, nodes, parent, depth)
    nodes.each_with_index do |node_data, index|
      doc_node = version.document_nodes.create!(
        parent: parent,
        tree_path: node_data[:path],
        element_type: node_data[:element_type],
        eid: node_data[:eid],
        num: node_data[:num],
        heading: node_data[:heading],
        content_text: node_data[:content],
        position: index,
        depth: depth
      )
      persist_nodes(version, node_data[:children], doc_node, depth + 1) if node_data[:children].present?
    end
  end
end
