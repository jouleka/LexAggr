require "test_helper"

class LegislationTest < ActiveSupport::TestCase
  setup do
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
  end

  test "valid legislation with required fields" do
    legislation = Legislation.new(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "General Data Protection Regulation",
      legislation_type: "regulation",
      year: 2016,
      status: "in_force"
    )
    assert legislation.valid?
  end

  test "invalid without frbr_uri" do
    legislation = Legislation.new(jurisdiction: @jurisdiction, title: "Test")
    assert_not legislation.valid?
    assert_includes legislation.errors[:frbr_uri], "can't be blank"
  end

  test "frbr_uri must be unique" do
    Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR")
    duplicate = Legislation.new(jurisdiction: @jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR Copy")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:frbr_uri], "has already been taken"
  end

  test "invalid without title" do
    legislation = Legislation.new(jurisdiction: @jurisdiction, frbr_uri: "/test/1")
    assert_not legislation.valid?
    assert_includes legislation.errors[:title], "can't be blank"
  end

  test "belongs to jurisdiction" do
    legislation = Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR")
    assert_equal @jurisdiction, legislation.jurisdiction
  end

  test "has many versions" do
    legislation = Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR")
    assert_respond_to legislation, :legislation_versions
  end

  test "in_force scope returns only in_force legislations" do
    in_force = Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR", status: "in_force")
    Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/dir/2006/112", title: "VAT Directive", status: "repealed")

    results = Legislation.in_force
    assert_includes results, in_force
    assert_equal 1, results.count
  end

  test "by_type scope filters by legislation_type" do
    regulation = Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR", legislation_type: "regulation")
    Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/dir/2006/112", title: "VAT Directive", legislation_type: "directive")

    results = Legislation.by_type("regulation")
    assert_includes results, regulation
    assert_equal 1, results.count
  end

  test "by_year scope filters by year" do
    leg_2016 = Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR", year: 2016)
    Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/dir/2006/112", title: "VAT Directive", year: 2006)

    results = Legislation.by_year(2016)
    assert_includes results, leg_2016
    assert_equal 1, results.count
  end

  test "search_full_text scope finds legislation by title fragment" do
    gdpr = Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "General Data Protection Regulation")
    Legislation.create!(jurisdiction: @jurisdiction, frbr_uri: "/eli/dir/2006/112", title: "Value Added Tax Directive")

    results = Legislation.search_full_text("Protection")
    assert_includes results, gdpr
    assert_not_includes results, Legislation.find_by(frbr_uri: "/eli/dir/2006/112")
  end
end
