require "test_helper"

class Parsers::AknParserTest < ActiveSupport::TestCase
  setup do
    xml = File.read(Rails.root.join("test/fixtures/files/sample_akn.xml"))
    @parser = Parsers::AknParser.new(xml)
  end

  test "extracts metadata" do
    metadata = @parser.extract_metadata
    assert_equal "/eli/reg/2016/679", metadata[:frbr_uri]
    assert_equal "2016-04-27", metadata[:date]
    assert_equal "eu", metadata[:country]
    assert_equal "eng", metadata[:language]
  end

  test "extracts title" do
    metadata = @parser.extract_metadata
    assert_includes metadata[:title], "General Data Protection Regulation"
  end

  test "extracts body hierarchy" do
    nodes = @parser.extract_body_hierarchy
    assert_equal 1, nodes.length

    chapter = nodes.first
    assert_equal "chapter", chapter[:element_type]
    assert_equal "chp_1", chapter[:eid]
    assert_equal "General provisions", chapter[:heading]

    article = chapter[:children].first
    assert_equal "article", article[:element_type]
    assert_equal "art_1", article[:eid]

    paragraph = article[:children].first
    assert_equal "paragraph", paragraph[:element_type]
    assert_includes paragraph[:content], "protection of natural persons"
  end
end
