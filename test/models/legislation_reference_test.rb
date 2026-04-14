require "test_helper"

class LegislationReferenceTest < ActiveSupport::TestCase
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "EU", jurisdiction_type: "supranational")
    @source = Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/test/ref/1", title: "Source Act", legislation_type: "regulation", status: "in_force")
    @target = Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/test/ref/2", title: "Target Act", legislation_type: "directive", status: "in_force")
  end

  test "valid reference" do
    ref = LegislationReference.new(source_legislation: @source, target_legislation: @target, reference_type: "cites")
    assert ref.valid?
  end

  test "invalid without reference_type" do
    ref = LegislationReference.new(source_legislation: @source, target_legislation: @target)
    assert_not ref.valid?
  end

  test "invalid with unknown reference_type" do
    ref = LegislationReference.new(source_legislation: @source, target_legislation: @target, reference_type: "unknown")
    assert_not ref.valid?
  end

  test "unique per source-target-type combination" do
    LegislationReference.create!(source_legislation: @source, target_legislation: @target, reference_type: "cites")
    duplicate = LegislationReference.new(source_legislation: @source, target_legislation: @target, reference_type: "cites")
    assert_not duplicate.valid?
  end

  test "scopes filter by type" do
    LegislationReference.create!(source_legislation: @source, target_legislation: @target, reference_type: "cites")
    LegislationReference.create!(source_legislation: @source, target_legislation: @target, reference_type: "amends")
    assert_equal 1, LegislationReference.cites.count
    assert_equal 1, LegislationReference.amends.count
  end

  test "legislation has outgoing and incoming references" do
    LegislationReference.create!(source_legislation: @source, target_legislation: @target, reference_type: "amends")
    assert_includes @source.referenced_legislations, @target
    assert_includes @target.referencing_legislations, @source
  end
end
