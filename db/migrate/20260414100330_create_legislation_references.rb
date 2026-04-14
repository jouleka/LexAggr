class CreateLegislationReferences < ActiveRecord::Migration[8.0]
  def change
    create_table :legislation_references do |t|
      t.references :source_legislation, null: false, foreign_key: { to_table: :legislations }
      t.references :target_legislation, null: false, foreign_key: { to_table: :legislations }
      t.string :reference_type, null: false
      t.text :reference_text
      t.timestamps
    end

    add_index :legislation_references, [:source_legislation_id, :target_legislation_id, :reference_type],
              unique: true, name: "idx_legislation_refs_unique"
  end
end
