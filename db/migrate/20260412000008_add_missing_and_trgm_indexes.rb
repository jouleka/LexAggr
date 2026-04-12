class AddMissingAndTrgmIndexes < ActiveRecord::Migration[8.0]
  def change
    # Missing plan indexes
    add_index :legislations, :celex_number
    add_index :legislations, :eli_uri
    add_index :legislations, :status

    # pg_trgm fuzzy search indexes
    add_index :legislations, :title, using: :gin, opclass: :gin_trgm_ops, name: "index_legislations_on_title_trgm"
    add_index :document_nodes, :heading, using: :gin, opclass: :gin_trgm_ops, name: "index_document_nodes_on_heading_trgm"
  end
end
