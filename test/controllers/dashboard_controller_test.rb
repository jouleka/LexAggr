require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    get root_url
    assert_response :success
  end
end
