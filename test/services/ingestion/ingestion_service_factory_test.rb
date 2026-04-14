require "test_helper"

class Ingestion::IngestionServiceFactoryTest < ActiveSupport::TestCase
  test "returns EurlexSparqlService for eu" do
    service = Ingestion::IngestionServiceFactory.for("eu")
    assert_kind_of Ingestion::EurlexSparqlService, service
  end

  test "raises KeyError for unknown jurisdiction" do
    assert_raises(KeyError) { Ingestion::IngestionServiceFactory.for("xx") }
  end

  test "registered? returns true for known jurisdictions" do
    assert Ingestion::IngestionServiceFactory.registered?("eu")
  end

  test "registered? returns false for unknown jurisdictions" do
    assert_not Ingestion::IngestionServiceFactory.registered?("xx")
  end

  test "returns UkLegislationService for gb" do
    service = Ingestion::IngestionServiceFactory.for("gb")
    assert_kind_of Ingestion::UkLegislationService, service
  end

  test "returns FinlexService for fi" do
    service = Ingestion::IngestionServiceFactory.for("fi")
    assert_kind_of Ingestion::FinlexService, service
  end

  test "returns PolandEliService for pl" do
    service = Ingestion::IngestionServiceFactory.for("pl")
    assert_kind_of Ingestion::PolandEliService, service
  end

  test "returns SpainBoeService for es" do
    service = Ingestion::IngestionServiceFactory.for("es")
    assert_kind_of Ingestion::SpainBoeService, service
  end

  test "registered_codes includes all 5 jurisdictions" do
    codes = Ingestion::IngestionServiceFactory.registered_codes
    assert_includes codes, "eu"
    assert_includes codes, "gb"
    assert_includes codes, "fi"
    assert_includes codes, "pl"
    assert_includes codes, "es"
  end
end
