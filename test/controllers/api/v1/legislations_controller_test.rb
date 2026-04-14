require "test_helper"

class Api::V1::LegislationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "apileg@example.com", password: "password123", password_confirmation: "password123")
    @headers = { "Authorization" => "Bearer #{@user.api_token}" }
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @legislation = Legislation.create!(
      jurisdiction: jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "GDPR",
      legislation_type: "regulation",
      year: 2016,
      status: "in_force"
    )
  end

  test "index returns JSON list" do
    get api_v1_legislations_url, headers: @headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["data"].length
    assert_equal "GDPR", json["data"][0]["title"]
    assert json["meta"]["total"].present?
  end

  test "index filters by jurisdiction" do
    get api_v1_legislations_url(jurisdiction: "eu"), headers: @headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["data"].length
  end

  test "index filters by type" do
    get api_v1_legislations_url(type: "directive"), headers: @headers, as: :json
    json = JSON.parse(response.body)
    assert_equal 0, json["data"].length
  end

  test "index supports pagination" do
    get api_v1_legislations_url(page: 1, per_page: 1), headers: @headers, as: :json
    json = JSON.parse(response.body)
    assert_equal 1, json["meta"]["per_page"]
  end

  test "show returns legislation detail" do
    get api_v1_legislation_url(@legislation), headers: @headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "GDPR", json["data"]["title"]
    assert_equal "eu", json["data"]["jurisdiction"]["code"]
  end

  test "requires authentication" do
    get api_v1_legislations_url, as: :json
    assert_response :unauthorized
  end
end
