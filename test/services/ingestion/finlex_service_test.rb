require "test_helper"

class Ingestion::FinlexServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::FinlexService.new
    @list_response = File.read(Rails.root.join("test/fixtures/files/finlex_list_response.json"))
    @sample_akn = File.read(Rails.root.join("test/fixtures/files/finlex_sample_akn.xml"))
  end

  test "fetch_document_list parses JSON list" do
    year_2025_data = [ { "akn_uri" => "/akn/fi/act/statute/2025/500/fin@", "status" => "AMENDED" } ].to_json
    year_2026_data = [
      { "akn_uri" => "/akn/fi/act/statute/2026/100/fin@", "status" => "NEW" },
      { "akn_uri" => "/akn/fi/act/statute/2026/101/fin@", "status" => "NEW" }
    ].to_json

    stub_request(:get, /opendata\.finlex\.fi.*\/list/)
      .with(query: hash_including("startYear" => "2025", "endYear" => "2025"))
      .to_return(status: 200, body: year_2025_data, headers: { "Content-Type" => "application/json" })

    stub_request(:get, /opendata\.finlex\.fi.*\/list/)
      .with(query: hash_including("startYear" => "2026", "endYear" => "2026"))
      .to_return(status: 200, body: year_2026_data, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Date.new(2025, 1, 1))
    assert_equal 3, results.length

    assert_equal "/akn/fi/act/statute/2025/500", results[0][:frbr_uri]
    assert_equal "2025", results[0][:year]
    assert_equal "fi/act/statute/2025/500", results[0][:source_identifier]

    assert_equal "/akn/fi/act/statute/2026/100", results[1][:frbr_uri]
    assert_equal "2026", results[1][:year]
    assert_equal "fi/act/statute/2026/100", results[1][:source_identifier]
  end

  test "fetch_document_list handles empty response" do
    stub_request(:get, /opendata\.finlex\.fi.*\/list/)
      .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_empty results
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /opendata\.finlex\.fi.*\/list/)
      .to_return(status: 500)

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_empty results
  end

  test "fetch_document retrieves AKN XML" do
    stub_request(:get, %r{opendata\.finlex\.fi.*/akn/fi/act/statute/2026/100/fin@})
      .to_return(status: 200, body: @sample_akn, headers: { "Content-Type" => "application/xml" })

    ref = { source_identifier: "fi/act/statute/2026/100", year: "2026", number: "100" }
    result = @service.fetch_document(ref: ref)

    assert_equal "fi/act/statute/2026/100", result[:source_identifier]
    assert_equal @sample_akn, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(@sample_akn), result[:content_hash]
  end

  test "fetch_document handles 404" do
    stub_request(:get, %r{opendata\.finlex\.fi.*/akn/fi/act/statute/2026/999/fin@})
      .to_return(status: 404)

    ref = { source_identifier: "fi/act/statute/2026/999", year: "2026", number: "999" }
    result = @service.fetch_document(ref: ref)
    assert_empty result
  end

  test "parse_akn_uri extracts year and number" do
    result = @service.send(:parse_akn_uri, "/akn/fi/act/statute/2026/100/fin@")
    assert_equal "2026", result[:year]
    assert_equal "100", result[:number]
    assert_equal "fi/act/statute/2026/100", result[:source_identifier]
    assert_equal "/akn/fi/act/statute/2026/100", result[:frbr_uri]
  end
end
