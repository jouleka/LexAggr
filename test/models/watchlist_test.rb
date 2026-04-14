require "test_helper"

class WatchlistTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "test@example.com", password: "password123", password_confirmation: "password123")
  end

  test "valid watchlist" do
    watchlist = Watchlist.new(user: @user, name: "My Watchlist")
    assert watchlist.valid?
  end

  test "invalid without name" do
    watchlist = Watchlist.new(user: @user, name: "")
    assert_not watchlist.valid?
  end

  test "name unique per user" do
    Watchlist.create!(user: @user, name: "My Watchlist")
    duplicate = Watchlist.new(user: @user, name: "My Watchlist")
    assert_not duplicate.valid?
  end

  test "default_for creates if not exists" do
    assert_difference "Watchlist.count", 1 do
      watchlist = Watchlist.default_for(@user)
      assert_equal "My Watchlist", watchlist.name
    end
  end

  test "default_for returns existing" do
    existing = Watchlist.create!(user: @user, name: "My Watchlist")
    assert_no_difference "Watchlist.count" do
      result = Watchlist.default_for(@user)
      assert_equal existing, result
    end
  end
end
