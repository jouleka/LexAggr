require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "api@example.com", password: "password123", password_confirmation: "password123")
  end

  test "valid token returns 200" do
    Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    get api_v1_jurisdictions_url, headers: { "Authorization" => "Bearer #{@user.api_token}" }, as: :json
    assert_response :success
  end

  test "invalid token returns 401" do
    get api_v1_jurisdictions_url, headers: { "Authorization" => "Bearer invalid" }, as: :json
    assert_response :unauthorized
  end

  test "missing token returns 401" do
    get api_v1_jurisdictions_url, as: :json
    assert_response :unauthorized
  end

  test "user gets api_token on creation" do
    assert @user.api_token.present?
    assert_equal 64, @user.api_token.length
  end
end
