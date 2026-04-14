require "test_helper"

class AlertPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "prefs@example.com", password: "password123", password_confirmation: "password123")
    post session_url, params: { email_address: "prefs@example.com", password: "password123" }
  end

  test "edit shows preferences" do
    get edit_alert_preferences_url
    assert_response :success
  end

  test "update changes frequency" do
    patch alert_preferences_url, params: { user: { alert_frequency: "weekly" } }
    assert_redirected_to edit_alert_preferences_path
    @user.reload
    assert_equal "weekly", @user.alert_frequency
  end

  test "update enables/disables email" do
    patch alert_preferences_url, params: { user: { alert_email_enabled: false } }
    @user.reload
    assert_equal false, @user.alert_email_enabled
  end

  test "requires authentication" do
    delete session_url
    get edit_alert_preferences_url
    assert_response :redirect
  end
end
