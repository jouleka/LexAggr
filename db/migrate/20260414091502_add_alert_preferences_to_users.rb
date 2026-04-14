class AddAlertPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :alert_frequency, :string, default: "daily", null: false
    add_column :users, :alert_email_enabled, :boolean, default: true, null: false
    add_column :users, :last_digest_sent_at, :datetime
  end
end
