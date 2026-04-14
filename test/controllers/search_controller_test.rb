require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get search_url
    assert_response :success
  end

  test "search with query returns results" do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    Legislation.create!(
      jurisdiction: jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "General Data Protection Regulation",
      legislation_type: "regulation",
      status: "in_force",
      year: 2016
    )
    get search_url(q: "protection")
    assert_response :success
  end

  test "search with jurisdiction filter" do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/test/facet/1", title: "Test Law", legislation_type: "act", status: "in_force")
    get search_url(q: "test", jurisdiction: "eu")
    assert_response :success
  end

  test "search without query shows all legislation" do
    get search_url
    assert_response :success
  end

  test "search with type filter" do
    get search_url(q: "test", type: "regulation")
    assert_response :success
  end
end
