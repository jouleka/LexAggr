require "test_helper"

class Ingestion::EurlexSparqlServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::EurlexSparqlService.new
    @sparql_response = File.read(Rails.root.join("test/fixtures/files/sparql_response.json"))
  end

  test "fetch_document_list returns parsed document references" do
    stub_request(:any, /publications\.europa\.eu\/webapi\/rdf\/sparql/)
      .to_return(status: 200, body: @sparql_response, headers: { "Content-Type" => "application/sparql-results+json" })

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_equal 2, results.length
    assert_equal "32016R0679", results[0][:celex_number]
    assert_equal "32024R1689", results[1][:celex_number]
    assert_equal "regulation", results[0][:legislation_type]
  end

  test "fetch_document_list handles empty results" do
    empty_response = { "results" => { "bindings" => [] } }.to_json
    stub_request(:any, /publications\.europa\.eu\/webapi\/rdf\/sparql/)
      .to_return(status: 200, body: empty_response, headers: { "Content-Type" => "application/sparql-results+json" })

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document_list handles HTTP errors gracefully" do
    stub_request(:any, /publications\.europa\.eu\/webapi\/rdf\/sparql/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document retrieves XML content" do
    cellar_url = "https://eur-lex.europa.eu/legal-content/EN/TXT/XML/?uri=CELEX:32016R0679"
    sample_xml = '<akomaNtoso xmlns="http://docs.oasis-open.org/legaldocml/ns/akn/3.0"><act name="regulation"></act></akomaNtoso>'

    stub_request(:get, cellar_url)
      .to_return(status: 200, body: sample_xml, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { celex_number: "32016R0679" })
    assert_equal sample_xml, result[:raw_xml]
    assert_equal "32016R0679", result[:celex_number]
  end

  test "build_sparql_query includes date filter" do
    query = @service.send(:build_sparql_query, since: Date.new(2026, 1, 1), limit: 10)
    assert_includes query, "2026-01-01"
    assert_includes query, "LIMIT 10"
    assert_includes query, "cdm:work_has_resource-type"
  end

  test "resource_type_to_legislation_type maps correctly" do
    assert_equal "regulation", @service.send(:resource_type_to_legislation_type, "REG")
    assert_equal "directive", @service.send(:resource_type_to_legislation_type, "DIR")
    assert_equal "decision", @service.send(:resource_type_to_legislation_type, "DEC")
    assert_equal "other", @service.send(:resource_type_to_legislation_type, "UNKNOWN")
  end
end
