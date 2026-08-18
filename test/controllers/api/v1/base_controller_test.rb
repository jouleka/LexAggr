require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "api@example.com", password: "password123", password_confirmation: "password123")
    @api_token = @user.rotate_api_token!
  end

  test "valid token returns 200" do
    Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    get api_v1_jurisdictions_url, headers: { "Authorization" => "Bearer #{@api_token}" }, as: :json
    assert_response :success
  end

  test "invalid token returns 401" do
    get api_v1_jurisdictions_url, headers: { "Authorization" => "Bearer invalid" }, as: :json
    assert_response :unauthorized
  end

  test "rejects an authorization header with trailing content" do
    get api_v1_jurisdictions_url,
      headers: { "Authorization" => "Bearer #{@api_token} trailing" },
      as: :json

    assert_response :unauthorized
  end

  test "missing token returns 401" do
    get api_v1_jurisdictions_url, as: :json
    assert_response :unauthorized
  end

  test "token rotation returns a raw token but stores only its digest" do
    assert_equal 64, @api_token.length
    assert_equal Digest::SHA256.hexdigest(@api_token), @user.reload.api_token_digest
    assert_not_equal @api_token, @user.api_token_digest
  end
end
