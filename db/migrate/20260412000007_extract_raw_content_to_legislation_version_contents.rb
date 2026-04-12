class ExtractRawContentToLegislationVersionContents < ActiveRecord::Migration[8.0]
  def up
    create_table :legislation_version_contents do |t|
      t.references :legislation_version, null: false, foreign_key: true, index: { unique: true }
      t.text :raw_xml
      t.text :raw_html
      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO legislation_version_contents (legislation_version_id, raw_xml, raw_html, created_at, updated_at)
          SELECT id, raw_xml, raw_html, created_at, updated_at
          FROM legislation_versions
          WHERE raw_xml IS NOT NULL OR raw_html IS NOT NULL
        SQL
      end
    end

    remove_column :legislation_versions, :raw_xml, :text
    remove_column :legislation_versions, :raw_html, :text
  end

  def down
    add_column :legislation_versions, :raw_xml, :text
    add_column :legislation_versions, :raw_html, :text

    execute <<-SQL
      UPDATE legislation_versions
      SET raw_xml = lvc.raw_xml, raw_html = lvc.raw_html
      FROM legislation_version_contents lvc
      WHERE legislation_versions.id = lvc.legislation_version_id
    SQL

    drop_table :legislation_version_contents
  end
end
