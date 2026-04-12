class CreateDocumentNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :document_nodes do |t|
      t.references :legislation_version, null: false, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :document_nodes }
      t.column :tree_path, :ltree
      t.string :element_type
      t.string :eid
      t.string :num
      t.string :heading
      t.text :content_text
      t.integer :position
      t.integer :depth
      t.column :searchable, :tsvector

      t.timestamps
    end

    add_index :document_nodes, :tree_path, using: :gist
    add_index :document_nodes, :searchable, using: :gin
    add_index :document_nodes, [ :legislation_version_id, :eid ]
  end
end
