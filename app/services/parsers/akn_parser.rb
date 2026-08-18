module Parsers
  class AknParser < BaseParser
    AKN_NS = { "akn" => "http://docs.oasis-open.org/legaldocml/ns/akn/3.0" }.freeze

    HIERARCHICAL = %w[part chapter title section article
                      paragraph subparagraph clause point indent].freeze

    def extract_metadata
      {
        frbr_uri: text_at("//akn:FRBRWork/akn:FRBRuri/@value", AKN_NS),
        title: text_at("//akn:preface/akn:longTitle//akn:docTitle", AKN_NS),
        date: text_at("//akn:FRBRWork/akn:FRBRdate/@date", AKN_NS),
        country: text_at("//akn:FRBRWork/akn:FRBRcountry/@value", AKN_NS),
        language: text_at("//akn:FRBRExpression/akn:FRBRlanguage/@language", AKN_NS)
      }
    end

    def extract_body_hierarchy
      body = @doc.at_xpath("//akn:body", AKN_NS)
      return [] unless body
      parse_children(body, [])
    end

    private

    def parse_children(node, path)
      node.children.select(&:element?).filter_map do |child|
        next unless HIERARCHICAL.include?(child.name)
        current_path = path + [ child["eId"] || child.name ]
        {
          element_type: child.name,
          eid: child["eId"],
          heading: child.at_xpath("akn:heading", AKN_NS)&.text&.strip,
          num: child.at_xpath("akn:num", AKN_NS)&.text&.strip,
          content: child.at_xpath("akn:content", AKN_NS)&.text&.strip,
          path: current_path.join("."),
          children: parse_children(child, current_path)
        }
      end
    end
  end
end
