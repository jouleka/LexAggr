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

  test "returns SwitzerlandFedlexService for ch" do
    service = Ingestion::IngestionServiceFactory.for("ch")
    assert_kind_of Ingestion::SwitzerlandFedlexService, service
  end

  test "returns FranceDilaService for fr" do
    service = Ingestion::IngestionServiceFactory.for("fr")
    assert_kind_of Ingestion::FranceDilaService, service
  end

  test "returns ItalyNormattivaService for it" do
    service = Ingestion::IngestionServiceFactory.for("it")
    assert_kind_of Ingestion::ItalyNormattivaService, service
  end

  test "returns GermanyGesetzeService for de" do
    service = Ingestion::IngestionServiceFactory.for("de")
    assert_kind_of Ingestion::GermanyGesetzeService, service
  end

  test "returns AustriaRisService for at" do
    service = Ingestion::IngestionServiceFactory.for("at")
    assert_kind_of Ingestion::AustriaRisService, service
  end

  test "returns SwedenRiksdagenService for se" do
    service = Ingestion::IngestionServiceFactory.for("se")
    assert_kind_of Ingestion::SwedenRiksdagenService, service
  end

  test "returns DenmarkRetsinformationService for dk" do
    service = Ingestion::IngestionServiceFactory.for("dk")
    assert_kind_of Ingestion::DenmarkRetsinformationService, service
  end

  test "returns NorwayLovdataService for no" do
    service = Ingestion::IngestionServiceFactory.for("no")
    assert_kind_of Ingestion::NorwayLovdataService, service
  end

  test "registered_codes includes all 13 jurisdictions" do
    codes = Ingestion::IngestionServiceFactory.registered_codes
    %w[eu gb fi pl es ch fr it de at se dk no].each do |code|
      assert_includes codes, code
    end
  end
end
