require "test_helper"

class Api::V1::JurisdictionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "apijur@example.com", password: "password123", password_confirmation: "password123")
    @headers = { "Authorization" => "Bearer #{@user.api_token}" }
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
  end

  test "index returns all jurisdictions" do
    get api_v1_jurisdictions_url, headers: @headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length >= 1
  end

  test "show returns jurisdiction with counts" do
    Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/test/1", title: "Test", legislation_type: "regulation", status: "in_force")
    get api_v1_jurisdiction_url("eu"), headers: @headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "eu", json["data"]["code"]
    assert_equal 1, json["data"]["legislation_count"]
  end
end
