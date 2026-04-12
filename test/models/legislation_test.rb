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
end
