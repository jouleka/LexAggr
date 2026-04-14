require "test_helper"

class Ingestion::NorwayLovdataServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::NorwayLovdataService.new
    @list_response = File.read(Rails.root.join("test/fixtures/files/norway_lovdata_list_response.xml"))
    @document_response = File.read(Rails.root.join("test/fixtures/files/norway_lovdata_document_response.xml"))
  end

  test "fetch_document_list parses XML law entries" do
    stub_request(:get, /api\.lovdata\.no\/api\/v1\/laws/)
      .to_return(status: 200, body: @list_response, headers: { "Content-Type" => "application/xml" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_equal 3, results.length

    first = results[0]
    assert_equal "LOV-2026-01-15-5", first[:source_identifier]
    assert_equal "Lov om personopplysninger (personopplysningsloven)", first[:title]
    assert_equal "act", first[:legislation_type]
    assert_equal "in_force", first[:status]
    assert_equal "/eli/no/lov/LOV-2026-01-15-5", first[:frbr_uri]

    second = results[1]
    assert_equal "FOR-2026-02-10-120", second[:source_identifier]
    assert_equal "regulation", second[:legislation_type]

    third = results[2]
    assert_equal "repealed", third[:status]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /api\.lovdata\.no\/api\/v1\/laws/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_empty results
  end

  test "fetch_document retrieves XML content" do
    stub_request(:get, "https://api.lovdata.no/api/v1/laws/LOV-2026-01-15-5")
      .to_return(status: 200, body: @document_response, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { id: "LOV-2026-01-15-5" })
    assert_equal "LOV-2026-01-15-5", result[:source_identifier]
    assert_equal @document_response, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(@document_response), result[:content_hash]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://api.lovdata.no/api/v1/laws/LOV-9999-01-01-0")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { id: "LOV-9999-01-01-0" })
    assert_empty result
  end

  test "map_document_type maps Norwegian types correctly" do
    assert_equal "act", @service.map_document_type("lov")
    assert_equal "regulation", @service.map_document_type("forskrift")
    assert_equal "decision", @service.map_document_type("vedtak")
    assert_equal "directive", @service.map_document_type("instruks")
    assert_equal "other", @service.map_document_type("unknown")
  end
end
