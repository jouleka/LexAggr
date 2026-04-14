require "test_helper"

class AlertDigestJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    # Disable alerts on fixture users so they don't interfere
    User.update_all(alert_email_enabled: false)

    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @user = User.create!(
      email_address: "alert@example.com",
      password: "password123",
      password_confirmation: "password123",
      alert_frequency: "daily",
      alert_email_enabled: true,
      last_digest_sent_at: 2.days.ago
    )
    @legislation = Legislation.create!(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/test/alert/1",
      title: "Test Regulation for Alerts",
      legislation_type: "regulation",
      status: "in_force"
    )
    watchlist = Watchlist.create!(user: @user, name: "My Watchlist")
    WatchlistItem.create!(watchlist: watchlist, legislation: @legislation, item_type: "specific_legislation")
  end

  test "sends digest to users with changes" do
    # Touch the legislation to simulate a change
    @legislation.update_column(:updated_at, Time.current)

    assert_enqueued_emails 1 do
      AlertDigestJob.perform_now
    end
  end

  test "does not send when no changes" do
    # Set last_digest_sent_at to future so nothing is "changed"
    @user.update_column(:last_digest_sent_at, 1.hour.from_now)

    assert_no_enqueued_emails do
      AlertDigestJob.perform_now
    end
  end

  test "does not send to users with alerts disabled" do
    @user.update_column(:alert_email_enabled, false)
    @legislation.update_column(:updated_at, Time.current)

    assert_no_enqueued_emails do
      AlertDigestJob.perform_now
    end
  end

  test "does not send to users with frequency none" do
    @user.update!(alert_frequency: "none")
    @legislation.update_column(:updated_at, Time.current)

    assert_no_enqueued_emails do
      AlertDigestJob.perform_now
    end
  end

  test "updates last_digest_sent_at after sending" do
    @legislation.update_column(:updated_at, Time.current)
    old_time = @user.last_digest_sent_at

    AlertDigestJob.perform_now
    @user.reload
    assert @user.last_digest_sent_at > old_time
  end
end
