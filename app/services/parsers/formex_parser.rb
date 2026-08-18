module Parsers
  class FormexParser < BaseParser
    DIVISION_TYPE_MAP = {
      "CHAPTER" => "chapter",
      "SECTION" => "section",
      "PART" => "part",
      "TITLE" => "title"
    }.freeze

    def extract_metadata
      {
        title: text_at("//TITLE/TI/P"),
        celex_number: text_at("//NO.CELEX"),
        date: text_at("//DATE/@ISO")
      }
    end

    def extract_body_hierarchy
      enacting = @doc.at_xpath("//ENACTING.TERMS")
      return [] unless enacting
      parse_formex_children(enacting, [])
    end

    private

    def parse_formex_children(node, path)
      results = []
      node.children.select(&:element?).each do |child|
        case child.name
        when "DIVISION"
          results << parse_division(child, path)
        when "ARTICLE"
          results << parse_article(child, path)
        end
      end
      results.compact
    end

    def parse_division(node, path)
      div_type = DIVISION_TYPE_MAP.fetch(node["TYPE"], "division")
      eid = node["ID"]
      current_path = path + [ eid || div_type ]
      {
        element_type: div_type,
        eid: eid,
        heading: node.at_xpath("TITLE/STI/P")&.text&.strip,
        num: node.at_xpath("TITLE/TI/P")&.text&.strip,
        content: nil,
        path: current_path.join("."),
        children: parse_formex_children(node, current_path)
      }
    end

    def parse_article(node, path)
      eid = node["ID"]
      current_path = path + [ eid || "article" ]
      children = node.xpath("PARAG").map do |parag|
        para_id = parag["ID"]
        para_path = current_path + [ para_id || "para" ]
        {
          element_type: "paragraph",
          eid: para_id,
          heading: nil,
          num: nil,
          content: parag.at_xpath("ALINEA/P")&.text&.strip,
          path: para_path.join("."),
          children: []
        }
      end
      {
        element_type: "article",
        eid: eid,
        heading: node.at_xpath("STI/P")&.text&.strip,
        num: node.at_xpath("TI/P")&.text&.strip,
        content: nil,
        path: current_path.join("."),
        children: children
      }
    end
  end
end
