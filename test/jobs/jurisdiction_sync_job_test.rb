require "test_helper"

class JurisdictionSyncJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
  end

  test "creates ingestion log and enqueues document jobs" do
    mock_results = [
      { celex_number: "32016R0679", title: "GDPR", frbr_uri: "/eli/celex/32016R0679", legislation_type: "regulation", date: "2016-04-27" }
    ]

    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document_list).returns(mock_results)

    assert_difference "IngestionLog.count", 1 do
      assert_enqueued_with(job: ParseLegislationDocumentJob) do
        JurisdictionSyncJob.perform_now("eu")
      end
    end

    log = IngestionLog.last
    assert_equal "completed", log.status
    assert_equal 1, log.documents_processed
  end

  test "marks log as failed on error" do
    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document_list).raises(StandardError, "Connection failed")

    JurisdictionSyncJob.perform_now("eu")

    log = IngestionLog.last
    assert_equal "failed", log.status
    assert_includes log.error_message, "Connection failed"
  end

  test "skips unregistered jurisdictions" do
    assert_no_difference "IngestionLog.count" do
      JurisdictionSyncJob.perform_now("xx")
    end
  end
end
