require "test_helper"

class LegislationsControllerTest < ActionDispatch::IntegrationTest
  setup do
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

  test "should get index" do
    get legislations_url
    assert_response :success
  end

  test "should get show" do
    get legislation_url(@legislation)
    assert_response :success
  end

  test "index filters by jurisdiction" do
    get legislations_url(jurisdiction: "eu")
    assert_response :success
  end
end
