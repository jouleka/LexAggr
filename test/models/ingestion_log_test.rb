require "test_helper"

class IngestionLogTest < ActiveSupport::TestCase
  setup do
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
  end

  test "valid ingestion log" do
    log = IngestionLog.new(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "running")
    assert log.valid?
  end

  test "invalid without jurisdiction" do
    log = IngestionLog.new(source_name: "cellar_sparql", status: "running")
    assert_not log.valid?
  end

  test "latest_for scope returns most recent log per source" do
    IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "completed", created_at: 1.hour.ago)
    latest = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "completed")
    result = IngestionLog.latest_for(@jurisdiction, "cellar_sparql")
    assert_equal latest, result
  end

  test "mark_completed! updates status and count" do
    log = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "running")
    log.mark_completed!(documents_processed: 42)
    log.reload
    assert_equal "completed", log.status
    assert_equal 42, log.documents_processed
  end

  test "mark_failed! updates status and error" do
    log = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "running")
    log.mark_failed!("Connection timeout")
    log.reload
    assert_equal "failed", log.status
    assert_equal "Connection timeout", log.error_message
  end

  test "recent scope orders by created_at descending" do
    old_log = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "completed", created_at: 2.hours.ago)
    new_log = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "running", created_at: 1.minute.ago)
    mid_log = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "completed", created_at: 1.hour.ago)

    results = IngestionLog.recent.to_a
    assert_equal [new_log, mid_log, old_log], results
  end
end
