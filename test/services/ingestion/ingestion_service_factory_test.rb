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
end
