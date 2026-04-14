require "test_helper"

class Ingestion::FranceDilaServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::FranceDilaService.new
    @directory_html = File.read(Rails.root.join("test/fixtures/files/france_dila_directory.html"))
    @sample_html = File.read(Rails.root.join("test/fixtures/files/france_legifrance_sample.html"))
  end

  test "fetch_document_list parses directory listing and filters by date" do
    stub_request(:get, "https://echanges.dila.gouv.fr/OPENDATA/LEGI/")
      .to_return(status: 200, body: @directory_html, headers: { "Content-Type" => "text/html" })

    results = @service.fetch_document_list(since: Date.new(2026, 3, 10))
    assert_equal 2, results.length

    first = results[0]
    assert_equal "LEGI_20260401-120000", first[:source_identifier]
    assert_equal "2026-04-01", first[:date]
    assert_includes first[:frbr_uri], "/eli/fr/legi/"
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, "https://echanges.dila.gouv.fr/OPENDATA/LEGI/")
      .to_return(status: 503)

    results = @service.fetch_document_list(since: Date.current)
    assert_empty results
  end

  test "fetch_document retrieves HTML from Legifrance" do
    stub_request(:get, "https://www.legifrance.gouv.fr/jorf/id/JORFTEXT000049563955")
      .to_return(status: 200, body: @sample_html, headers: { "Content-Type" => "text/html" })

    result = @service.fetch_document(ref: { source_identifier: "JORFTEXT000049563955" })
    assert_equal @sample_html, result[:raw_html]
    assert_equal Digest::SHA256.hexdigest(@sample_html), result[:content_hash]
    assert_equal "JORFTEXT000049563955", result[:source_identifier]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://www.legifrance.gouv.fr/jorf/id/INVALID000000000000")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { source_identifier: "INVALID000000000000" })
    assert_empty result
  end

  test "detect_legislation_type maps French titles correctly" do
    assert_equal "act", @service.detect_legislation_type("LOI n 2024-449 du 21 mai 2024")
    assert_equal "regulation", @service.detect_legislation_type("Ordonnance n 2024-100")
    assert_equal "regulation", @service.detect_legislation_type("Decret n 2024-200 du 15 mars")
    assert_equal "directive", @service.detect_legislation_type("Arrete du 10 avril 2024")
    assert_equal "decision", @service.detect_legislation_type("Decision du Conseil constitutionnel")
    assert_equal "other", @service.detect_legislation_type("Avis du Conseil d'Etat")
  end
end
