class CreateJurisdictions < ActiveRecord::Migration[8.0]
  def change
    create_table :jurisdictions do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :jurisdiction_type
      t.jsonb :api_config, default: {}

      t.timestamps
    end

    add_index :jurisdictions, :code, unique: true
  end
end
