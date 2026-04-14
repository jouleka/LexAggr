class CreateWatchlists < ActiveRecord::Migration[8.0]
  def change
    create_table :watchlists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false, default: "My Watchlist"
      t.timestamps
    end
    add_index :watchlists, [:user_id, :name], unique: true
  end
end
