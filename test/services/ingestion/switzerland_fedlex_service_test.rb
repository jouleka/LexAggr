require "test_helper"

class Ingestion::SwitzerlandFedlexServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::SwitzerlandFedlexService.new
    @sparql_response = File.read(Rails.root.join("test/fixtures/files/fedlex_sparql_response.json"))
    @sample_akn = File.read(Rails.root.join("test/fixtures/files/fedlex_sample_akn.xml"))
  end

  test "fetch_document_list returns parsed document references" do
    stub_request(:post, "https://fedlex.data.admin.ch/sparqlendpoint")
      .to_return(status: 200, body: @sparql_response, headers: { "Content-Type" => "application/sparql-results+json" })

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_equal 2, results.length

    first = results[0]
    assert_equal "https://fedlex.data.admin.ch/eli/cc/2020/624", first[:uri]
    assert_equal "Federal Act on Data Protection", first[:title]
    assert_equal "2020-09-25", first[:date]
    assert_equal "act", first[:legislation_type]
    assert_equal "/eli/ch/cc/2020/624", first[:frbr_uri]
  end

  test "fetch_document_list handles empty results" do
    empty_response = { "results" => { "bindings" => [] } }.to_json
    stub_request(:post, "https://fedlex.data.admin.ch/sparqlendpoint")
      .to_return(status: 200, body: empty_response, headers: { "Content-Type" => "application/sparql-results+json" })

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document_list handles HTTP errors gracefully" do
    stub_request(:post, "https://fedlex.data.admin.ch/sparqlendpoint")
      .to_return(status: 503)

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document retrieves AKN XML via content negotiation" do
    stub_request(:get, "https://fedlex.data.admin.ch/eli/cc/2020/624")
      .to_return(status: 200, body: @sample_akn, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { uri: "https://fedlex.data.admin.ch/eli/cc/2020/624" })
    assert_equal @sample_akn, result[:raw_xml]
    assert_equal "https://fedlex.data.admin.ch/eli/cc/2020/624", result[:uri]
    assert_equal Digest::SHA256.hexdigest(@sample_akn), result[:content_hash]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://fedlex.data.admin.ch/eli/cc/9999/000")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { uri: "https://fedlex.data.admin.ch/eli/cc/9999/000" })
    assert_empty result
  end

  test "build_sparql_query includes date filter and JOLux ontology" do
    query = @service.send(:build_sparql_query, since: Date.new(2022, 5, 1), limit: 50)
    assert_includes query, "2022-05-01"
    assert_includes query, "LIMIT 50"
    assert_includes query, "jolux:Act"
    assert_includes query, "jolux:dateDocument"
  end
end
