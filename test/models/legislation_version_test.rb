require "test_helper"

class LegislationVersionTest < ActiveSupport::TestCase
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @legislation = Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR")
  end

  test "valid version with required fields" do
    version = LegislationVersion.new(
      legislation: @legislation,
      version_uri: "/eli/reg/2016/679/en",
      language: "en",
      valid_from: Date.new(2018, 5, 25),
      version_type: "original"
    )
    assert version.valid?
  end

  test "invalid without version_uri" do
    version = LegislationVersion.new(legislation: @legislation)
    assert_not version.valid?
    assert_includes version.errors[:version_uri], "can't be blank"
  end

  test "version_uri must be unique" do
    LegislationVersion.create!(legislation: @legislation, version_uri: "/eli/reg/2016/679/en", language: "en", valid_from: Date.new(2018, 5, 25))
    duplicate = LegislationVersion.new(legislation: @legislation, version_uri: "/eli/reg/2016/679/en")
    assert_not duplicate.valid?
  end

  test "in_force_on scope returns versions valid on a date" do
    LegislationVersion.create!(legislation: @legislation, version_uri: "/eli/reg/2016/679/en/v1", language: "en", valid_from: Date.new(2018, 5, 25), valid_to: Date.new(2020, 1, 1))
    LegislationVersion.create!(legislation: @legislation, version_uri: "/eli/reg/2016/679/en/v2", language: "en", valid_from: Date.new(2020, 1, 2), valid_to: nil)
    results = LegislationVersion.in_force_on(Date.new(2019, 6, 1))
    assert_equal 1, results.count
    assert_equal "/eli/reg/2016/679/en/v1", results.first.version_uri
  end

  test "current scope returns versions with no valid_to" do
    LegislationVersion.create!(legislation: @legislation, version_uri: "/eli/reg/2016/679/en/v1", language: "en", valid_from: Date.new(2018, 5, 25), valid_to: Date.new(2020, 1, 1))
    current = LegislationVersion.create!(legislation: @legislation, version_uri: "/eli/reg/2016/679/en/v2", language: "en", valid_from: Date.new(2020, 1, 2), valid_to: nil)
    results = LegislationVersion.current
    assert_includes results, current
  end
end
