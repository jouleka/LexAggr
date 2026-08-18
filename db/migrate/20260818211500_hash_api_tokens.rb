class HashApiTokens < ActiveRecord::Migration[8.0]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    rename_column :users, :api_token, :api_token_digest
    MigrationUser.reset_column_information

    MigrationUser.where.not(api_token_digest: nil).find_each do |user|
      user.update_columns(api_token_digest: Digest::SHA256.hexdigest(user.api_token_digest))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "raw API tokens cannot be recovered from their digests"
  end
end
