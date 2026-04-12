require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get search_url
    assert_response :success
  end

  test "search with query" do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    Legislation.create!(
      jurisdiction: jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "General Data Protection Regulation",
      legislation_type: "regulation",
      status: "in_force"
    )
    get search_url(q: "protection")
    assert_response :success
  end
end
