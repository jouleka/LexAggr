require "test_helper"

class EliControllerTest < ActionDispatch::IntegrationTest
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @legislation = Legislation.create!(
      jurisdiction: jurisdiction,
      frbr_uri: "/eli/celex/32016R0679",
      celex_number: "32016R0679",
      eli_uri: "http://data.europa.eu/eli/reg/2016/679/oj",
      title: "GDPR",
      legislation_type: "regulation",
      status: "in_force"
    )
  end

  test "resolves by CELEX number" do
    get "/eli/celex/32016R0679"
    assert_response :moved_permanently
    assert_redirected_to legislation_path(@legislation)
  end

  test "resolves by frbr_uri match" do
    get "/eli/celex/32016R0679"
    assert_response :moved_permanently
  end

  test "returns 404 for unknown ELI" do
    get "/eli/unknown/path/here"
    assert_response :not_found
  end

  test "does not require authentication" do
    get "/eli/celex/32016R0679"
    assert_response :moved_permanently
  end
end
