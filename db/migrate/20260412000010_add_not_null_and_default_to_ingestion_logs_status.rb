class AddNotNullAndDefaultToIngestionLogsStatus < ActiveRecord::Migration[8.0]
  def change
    change_column_null :ingestion_logs, :status, false, "running"
    change_column_default :ingestion_logs, :status, "running"
  end
end
