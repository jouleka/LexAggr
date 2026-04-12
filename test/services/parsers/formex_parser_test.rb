require "test_helper"

class Parsers::FormexParserTest < ActiveSupport::TestCase
  setup do
    xml = File.read(Rails.root.join("test/fixtures/files/sample_formex.xml"))
    @parser = Parsers::FormexParser.new(xml)
  end

  test "extracts metadata" do
    metadata = @parser.extract_metadata
    assert_includes metadata[:title], "Council Regulation"
    assert_equal "32003R0001", metadata[:celex_number]
    assert_equal "20030116", metadata[:date]
  end

  test "extracts body hierarchy" do
    nodes = @parser.extract_body_hierarchy
    assert_equal 1, nodes.length

    chapter = nodes.first
    assert_equal "chapter", chapter[:element_type]
    assert_equal "chp_1", chapter[:eid]

    article = chapter[:children].first
    assert_equal "article", article[:element_type]
    assert_equal "art_1", article[:eid]
    assert_includes article[:heading], "Subject matter"
  end
end
