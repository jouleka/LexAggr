require "test_helper"

class Ingestion::PolandEliServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::PolandEliService.new
    @acts_response = File.read(Rails.root.join("test/fixtures/files/poland_acts_response.json"))
  end

  test "fetch_document_list parses JSON acts response" do
    stub_request(:get, /api\.sejm\.gov\.pl\/eli\/acts\/DU\/2026/)
      .to_return(status: 200, body: @acts_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Time.parse("2026-01-01"))
    assert_equal 3, results.length

    first = results[0]
    assert_equal "/eli/pl/DU/2026/100", first[:frbr_uri]
    assert_equal "act", first[:legislation_type]
    assert_equal 2026, first[:year]
    assert_equal "in_force", first[:status]

    second = results[1]
    assert_equal "/eli/pl/DU/2026/101", second[:frbr_uri]
    assert_equal "regulation", second[:legislation_type]
  end

  test "fetch_document_list maps Polish status correctly" do
    stub_request(:get, /api\.sejm\.gov\.pl\/eli\/acts\/DU\/2026/)
      .to_return(status: 200, body: @acts_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Time.parse("2026-01-01"))
    repealed = results.find { |r| r[:source_identifier] == "DU/2026/50" }
    assert_not_nil repealed
    assert_equal "repealed", repealed[:status]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /api\.sejm\.gov\.pl\/eli\/acts\/DU\/2026/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: Time.parse("2026-01-01"))
    assert_empty results
  end

  test "fetch_document retrieves HTML content" do
    html_body = "<html><body><h1>Ustawa</h1><p>Article 1...</p></body></html>"
    stub_request(:get, "https://api.sejm.gov.pl/eli/acts/DU/2026/100/text.html")
      .to_return(status: 200, body: html_body, headers: { "Content-Type" => "text/html" })

    result = @service.fetch_document(ref: { publisher: "DU", year: 2026, pos: 100 })
    assert_equal html_body, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(html_body), result[:content_hash]
    assert_equal "DU/2026/100", result[:source_identifier]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://api.sejm.gov.pl/eli/acts/DU/2026/999/text.html")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { publisher: "DU", year: 2026, pos: 999 })
    assert_empty result
  end

  test "polish_type_to_legislation_type maps correctly" do
    assert_equal "act", @service.polish_type_to_legislation_type("Ustawa")
    assert_equal "regulation", @service.polish_type_to_legislation_type("Rozporzadzenie")
    assert_equal "decision", @service.polish_type_to_legislation_type("Obwieszczenie")
    assert_equal "other", @service.polish_type_to_legislation_type("Unknown")
  end
end
