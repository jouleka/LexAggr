require "test_helper"

class JurisdictionTest < ActiveSupport::TestCase
  test "valid jurisdiction with required fields" do
    jurisdiction = Jurisdiction.new(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    assert jurisdiction.valid?
  end

  test "invalid without code" do
    jurisdiction = Jurisdiction.new(name: "European Union", jurisdiction_type: "supranational")
    assert_not jurisdiction.valid?
    assert_includes jurisdiction.errors[:code], "can't be blank"
  end

  test "invalid without name" do
    jurisdiction = Jurisdiction.new(code: "eu", jurisdiction_type: "supranational")
    assert_not jurisdiction.valid?
    assert_includes jurisdiction.errors[:name], "can't be blank"
  end

  test "code must be unique" do
    Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    duplicate = Jurisdiction.new(code: "eu", name: "EU Copy", jurisdiction_type: "supranational")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "api_config defaults to empty hash" do
    jurisdiction = Jurisdiction.create!(code: "gb", name: "United Kingdom", jurisdiction_type: "country")
    assert_equal({}, jurisdiction.api_config)
  end
end
