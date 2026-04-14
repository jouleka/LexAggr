require "test_helper"

class WatchlistItemTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "test@example.com", password: "password123", password_confirmation: "password123")
    @watchlist = Watchlist.create!(user: user, name: "My Watchlist")
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @legislation = Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR", legislation_type: "regulation", status: "in_force")
  end

  test "valid specific legislation item" do
    item = WatchlistItem.new(watchlist: @watchlist, legislation: @legislation, item_type: "specific_legislation")
    assert item.valid?
  end

  test "valid jurisdiction filter item" do
    jurisdiction = Jurisdiction.find_by(code: "eu")
    item = WatchlistItem.new(watchlist: @watchlist, jurisdiction: jurisdiction, legislation_type: "regulation", item_type: "jurisdiction_filter")
    assert item.valid?
  end

  test "invalid without item_type" do
    item = WatchlistItem.new(watchlist: @watchlist, legislation: @legislation, item_type: "")
    assert_not item.valid?
  end

  test "legislation unique per watchlist" do
    WatchlistItem.create!(watchlist: @watchlist, legislation: @legislation, item_type: "specific_legislation")
    duplicate = WatchlistItem.new(watchlist: @watchlist, legislation: @legislation, item_type: "specific_legislation")
    assert_not duplicate.valid?
  end
end
