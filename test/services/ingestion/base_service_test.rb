require "test_helper"

class Ingestion::BaseServiceTest < ActiveSupport::TestCase
  test "fetch_document_list raises NotImplementedError" do
    service = Ingestion::BaseService.new
    assert_raises(NotImplementedError) { service.fetch_document_list(since: 1.day.ago) }
  end

  test "fetch_document raises NotImplementedError" do
    service = Ingestion::BaseService.new
    assert_raises(NotImplementedError) { service.fetch_document(ref: "test") }
  end

  test "http_client returns a Faraday connection with retry" do
    service = Ingestion::BaseService.new
    client = service.send(:http_client)
    assert_kind_of Faraday::Connection, client
  end

  test "compute_content_hash returns SHA-256 hex digest" do
    service = Ingestion::BaseService.new
    hash = service.send(:compute_content_hash, "test content")
    assert_equal Digest::SHA256.hexdigest("test content"), hash
  end
end
