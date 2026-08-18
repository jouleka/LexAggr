require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "apisearch@example.com", password: "password123", password_confirmation: "password123")
    @headers = { "Authorization" => "Bearer #{@user.rotate_api_token!}" }
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/test/search/1", title: "General Data Protection Regulation", legislation_type: "regulation", status: "in_force", year: 2016)
  end

  test "search returns results with facets" do
    get api_v1_search_url(q: "protection"), headers: @headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length >= 1
    assert json["facets"].present?
    assert json["facets"]["jurisdictions"].present?
  end

  test "search requires query param" do
    get api_v1_search_url, headers: @headers, as: :json
    assert_response :bad_request
  end

  test "search filters by jurisdiction" do
    get api_v1_search_url(q: "protection", jurisdiction: "eu"), headers: @headers, as: :json
    assert_response :success
  end

  test "search requires authentication" do
    get api_v1_search_url(q: "test"), as: :json
    assert_response :unauthorized
  end
end
