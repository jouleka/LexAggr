require "test_helper"

class Ingestion::AustriaRisServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::AustriaRisService.new
    @search_response = File.read(Rails.root.join("test/fixtures/files/austria_ris_search_response.xml"))
    @document_response = File.read(Rails.root.join("test/fixtures/files/austria_ris_document.xml"))
  end

  test "fetch_document_list parses XML search results" do
    stub_request(:get, /data\.bka\.gv\.at\/ris\/api\/v2\.6\/Bundesrecht/)
      .to_return(status: 200, body: @search_response, headers: { "Content-Type" => "application/xml" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_equal 2, results.length

    first = results[0]
    assert_equal "NOR40263001", first[:source_identifier]
    assert_equal "Datenschutzgesetz 2026", first[:title]
    assert_equal "act", first[:legislation_type]
    assert_equal "/eli/at/bgbl/NOR40263001", first[:frbr_uri]

    second = results[1]
    assert_equal "NOR40263002", second[:source_identifier]
    assert_equal "regulation", second[:legislation_type]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /data\.bka\.gv\.at\/ris\/api\/v2\.6\/Bundesrecht/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_empty results
  end

  test "fetch_document retrieves document XML" do
    stub_request(:get, /data\.bka\.gv\.at\/ris\/api\/v2\.6\/Bundesrecht/)
      .to_return(status: 200, body: @document_response, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { document_number: "NOR40263001" })
    assert_equal "NOR40263001", result[:source_identifier]
    assert_equal @document_response, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(@document_response), result[:content_hash]
  end

  test "fetch_document handles 404" do
    stub_request(:get, /data\.bka\.gv\.at\/ris\/api\/v2\.6\/Bundesrecht/)
      .to_return(status: 404)

    result = @service.fetch_document(ref: { document_number: "NOR99999999" })
    assert_empty result
  end

  test "map_document_type maps Austrian types correctly" do
    assert_equal "act", @service.map_document_type("BG")
    assert_equal "act", @service.map_document_type("BVG")
    assert_equal "regulation", @service.map_document_type("V")
    assert_equal "decision", @service.map_document_type("E")
    assert_equal "other", @service.map_document_type("Unknown")
  end
end
