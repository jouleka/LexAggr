require "test_helper"

class Ingestion::DenmarkRetsinformationServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::DenmarkRetsinformationService.new
    @list_response = File.read(Rails.root.join("test/fixtures/files/denmark_retsinformation_list_response.json"))
    @document_response = File.read(Rails.root.join("test/fixtures/files/denmark_retsinformation_document_response.json"))
    @service.stubs(:throttle!)
  end

  test "fetch_document_list parses JSON document list" do
    stub_request(:get, /api\.retsinformation\.dk\/api\/v1\/documents/)
      .to_return(status: 200, body: @list_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_equal 3, results.length

    first = results[0]
    assert_equal "240001", first[:source_identifier]
    assert_equal "Lov om databeskyttelse", first[:title]
    assert_equal "act", first[:legislation_type]
    assert_equal "in_force", first[:status]
    assert_equal "/eli/dk/ret/240001", first[:frbr_uri]

    second = results[1]
    assert_equal "regulation", second[:legislation_type]

    third = results[2]
    assert_equal "repealed", third[:status]
    assert_equal "directive", third[:legislation_type]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /api\.retsinformation\.dk\/api\/v1\/documents/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_empty results
  end

  test "fetch_document retrieves document JSON" do
    stub_request(:get, "https://api.retsinformation.dk/api/v1/documents/240001")
      .to_return(status: 200, body: @document_response, headers: { "Content-Type" => "application/json" })

    result = @service.fetch_document(ref: { id: 240001 })
    assert_equal "240001", result[:source_identifier]
    assert_equal @document_response, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(@document_response), result[:content_hash]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://api.retsinformation.dk/api/v1/documents/999999")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { id: 999999 })
    assert_empty result
  end

  test "map_document_type maps Danish types correctly" do
    assert_equal "act", @service.map_document_type("LOV")
    assert_equal "act", @service.map_document_type("LBK")
    assert_equal "regulation", @service.map_document_type("BEK")
    assert_equal "directive", @service.map_document_type("CIR")
    assert_equal "decision", @service.map_document_type("AFG")
    assert_equal "other", @service.map_document_type("Unknown")
  end
end
