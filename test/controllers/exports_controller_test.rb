require "test_helper"

class ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @legislation = Legislation.create!(
      jurisdiction: jurisdiction,
      frbr_uri: "/test/export/1",
      celex_number: "32016R0679",
      title: "GDPR",
      legislation_type: "regulation",
      year: 2016,
      status: "in_force"
    )
  end

  test "legislation CSV export" do
    get export_legislation_csv_path(@legislation)
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "GDPR"
    assert_includes response.body, "32016R0679"
  end

  test "legislation PDF export" do
    get export_legislation_pdf_path(@legislation)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "search CSV export" do
    get export_search_csv_path(q: "GDPR")
    assert_response :success
    assert_equal "text/csv", response.media_type
  end

  test "search CSV export without query" do
    get export_search_csv_path
    assert_response :success
    assert_includes response.body, "GDPR"
  end

  test "CSV export neutralizes spreadsheet formulas from imported data" do
    @legislation.update!(title: '=HYPERLINK("https://example.test", "click")')

    get export_legislation_csv_path(@legislation)

    title_row = CSV.parse(response.body).find { |row| row.first == "Title" }
    assert_equal '\'=HYPERLINK("https://example.test", "click")', title_row.second
  end

  test "exports do not require authentication" do
    get export_legislation_csv_path(@legislation)
    assert_response :success
  end
end
