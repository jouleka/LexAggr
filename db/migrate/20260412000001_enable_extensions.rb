class EnableExtensions < ActiveRecord::Migration[8.0]
  def change
    enable_extension "ltree"
    enable_extension "pg_trgm"
  end
end
