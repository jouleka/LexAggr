class CreateLegislationVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :legislation_versions do |t|
      t.references :legislation, null: false, foreign_key: true
      t.string :version_uri, null: false
      t.string :language, default: "en"
      t.date :valid_from
      t.date :valid_to
      t.date :publication_date
      t.string :version_type
      t.text :raw_xml
      t.text :raw_html

      t.timestamps
    end

    add_index :legislation_versions, :version_uri, unique: true
    add_index :legislation_versions, [ :valid_from, :valid_to ]
  end
end
