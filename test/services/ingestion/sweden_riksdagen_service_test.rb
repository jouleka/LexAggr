require "test_helper"

class Ingestion::SwedenRiksdagenServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::SwedenRiksdagenService.new
    @list_response = File.read(Rails.root.join("test/fixtures/files/sweden_dokumentlista_response.json"))
    @document_response = File.read(Rails.root.join("test/fixtures/files/sweden_dokument_response.json"))
  end

  test "fetch_document_list parses JSON document list" do
    stub_request(:get, /data\.riksdagen\.se\/dokumentlista/)
      .to_return(status: 200, body: @list_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_equal 3, results.length

    first = results[0]
    assert_equal "SFS-2026-100", first[:source_identifier]
    assert_equal "Lag (2026:100) om dataskydd", first[:title]
    assert_equal "act", first[:legislation_type]
    assert_equal "/eli/se/sfs/SFS-2026-100", first[:frbr_uri]

    third = results[2]
    assert_equal "PROP-2026-50", third[:source_identifier]
    assert_equal "other", third[:legislation_type]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /data\.riksdagen\.se\/dokumentlista/)
      .to_return(status: 500)

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_empty results
  end

  test "fetch_document retrieves JSON content" do
    stub_request(:get, "https://data.riksdagen.se/dokument/SFS-2026-100.json")
      .to_return(status: 200, body: @document_response, headers: { "Content-Type" => "application/json" })

    result = @service.fetch_document(ref: { dok_id: "SFS-2026-100" })
    assert_equal "SFS-2026-100", result[:source_identifier]
    assert_equal @document_response, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(@document_response), result[:content_hash]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://data.riksdagen.se/dokument/SFS-9999-999.json")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { dok_id: "SFS-9999-999" })
    assert_empty result
  end

  test "map_document_type maps Swedish types correctly" do
    assert_equal "act", @service.map_document_type("sfs")
    assert_equal "other", @service.map_document_type("prop")
    assert_equal "decision", @service.map_document_type("bet")
    assert_equal "regulation", @service.map_document_type("ds")
    assert_equal "other", @service.map_document_type("unknown")
  end
end
