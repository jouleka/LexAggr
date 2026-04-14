require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "auth_test@example.com", password: "password123", password_confirmation: "password123")
  end

  test "public pages accessible without login" do
    Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational") unless Jurisdiction.exists?(code: "eu")

    get root_url
    assert_response :success

    get legislations_url
    assert_response :success

    get search_url
    assert_response :success
  end

  test "admin pages redirect to login" do
    get admin_ingestion_logs_url
    assert_response :redirect
  end

  test "can sign in" do
    post session_url, params: { email_address: "auth_test@example.com", password: "password123" }
    assert_redirected_to root_url
  end
end
