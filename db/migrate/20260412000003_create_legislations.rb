class CreateLegislations < ActiveRecord::Migration[8.0]
  def change
    create_table :legislations do |t|
      t.references :jurisdiction, null: false, foreign_key: true
      t.string :frbr_uri, null: false
      t.string :celex_number
      t.string :eli_uri
      t.string :title, null: false
      t.string :legislation_type
      t.integer :year
      t.string :status
      t.string :source_identifier
      t.string :content_hash
      t.column :searchable, :tsvector

      t.timestamps
    end

    add_index :legislations, :frbr_uri, unique: true
    add_index :legislations, :searchable, using: :gin
  end
end
