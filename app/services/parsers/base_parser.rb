module Parsers
  class BaseParser
    def initialize(xml_string)
      @doc = Nokogiri::XML(xml_string) { |c| c.strict.noblanks }
    end

    def extract_metadata
      raise NotImplementedError
    end

    def extract_body_hierarchy
      raise NotImplementedError
    end

    private

    def text_at(xpath, namespaces = {})
      @doc.at_xpath(xpath, namespaces)&.text&.strip
    end
  end
end
