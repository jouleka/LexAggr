class CreateWatchlistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :watchlist_items do |t|
      t.references :watchlist, null: false, foreign_key: true
      t.references :legislation, foreign_key: true
      t.references :jurisdiction, foreign_key: true
      t.string :legislation_type
      t.string :item_type, null: false, default: "specific_legislation"
      t.timestamps
    end
    add_index :watchlist_items, [:watchlist_id, :legislation_id], unique: true, where: "legislation_id IS NOT NULL", name: "idx_watchlist_items_unique_legislation"
  end
end
