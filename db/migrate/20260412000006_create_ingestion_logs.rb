class CreateIngestionLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ingestion_logs do |t|
      t.references :jurisdiction, null: false, foreign_key: true
      t.string :source_name
      t.string :status
      t.integer :documents_processed, default: 0
      t.string :last_etag
      t.datetime :last_modified_at
      t.text :error_message

      t.timestamps
    end

    add_index :ingestion_logs, [ :jurisdiction_id, :source_name, :created_at ]
  end
end
