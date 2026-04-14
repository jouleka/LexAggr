require "test_helper"

class Ingestion::ItalyNormattivaServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::ItalyNormattivaService.new
    @search_response = File.read(Rails.root.join("test/fixtures/files/normattiva_search_response.json"))
    @act_html = File.read(Rails.root.join("test/fixtures/files/normattiva_act_response.html"))
  end

  test "fetch_document_list parses JSON search results" do
    stub_request(:get, /api\.normattiva\.it.*ricerca\/predefinita/)
      .to_return(status: 200, body: @search_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_equal 3, results.length

    first = results[0]
    assert_equal "26G00050", first[:source_identifier]
    assert_equal "act", first[:legislation_type]
    assert_equal "2026-03-28", first[:date]
    assert_equal "in_force", first[:status]

    second = results[1]
    assert_equal "26G00048", second[:source_identifier]
    assert_equal "regulation", second[:legislation_type]
  end

  test "fetch_document_list maps Italian status correctly" do
    stub_request(:get, /api\.normattiva\.it.*ricerca\/predefinita/)
      .to_return(status: 200, body: @search_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    repealed = results.find { |r| r[:source_identifier] == "26G00030" }
    assert_not_nil repealed
    assert_equal "repealed", repealed[:status]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /api\.normattiva\.it.*ricerca\/predefinita/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_empty results
  end

  test "fetch_document retrieves HTML content" do
    stub_request(:get, "https://api.normattiva.it/t/normattiva.api/bff-opendata/v1/api/v1/atti/26G00050/testo")
      .to_return(status: 200, body: @act_html, headers: { "Content-Type" => "text/html" })

    result = @service.fetch_document(ref: { source_identifier: "26G00050" })
    assert_equal @act_html, result[:raw_html]
    assert_equal Digest::SHA256.hexdigest(@act_html), result[:content_hash]
    assert_equal "26G00050", result[:source_identifier]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://api.normattiva.it/t/normattiva.api/bff-opendata/v1/api/v1/atti/INVALID/testo")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { source_identifier: "INVALID" })
    assert_empty result
  end

  test "italian_type_to_legislation_type maps correctly" do
    assert_equal "act", @service.italian_type_to_legislation_type("LEGGE")
    assert_equal "regulation", @service.italian_type_to_legislation_type("DECRETO LEGISLATIVO")
    assert_equal "regulation", @service.italian_type_to_legislation_type("DECRETO LEGGE")
    assert_equal "directive", @service.italian_type_to_legislation_type("DECRETO MINISTERIALE")
    assert_equal "decision", @service.italian_type_to_legislation_type("DECISIONE")
    assert_equal "other", @service.italian_type_to_legislation_type("UNKNOWN")
  end
end
