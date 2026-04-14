require "test_helper"

class WatchlistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "watcher@example.com", password: "password123", password_confirmation: "password123")
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @legislation = Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/eli/test/1", title: "Test Act", legislation_type: "regulation", status: "in_force")
    # Log in
    post session_url, params: { email_address: "watcher@example.com", password: "password123" }
  end

  test "index requires authentication" do
    delete session_url  # log out
    get watchlists_url
    assert_response :redirect
  end

  test "index shows watchlists" do
    get watchlists_url
    assert_response :success
  end

  test "watch adds legislation to default watchlist" do
    assert_difference "WatchlistItem.count", 1 do
      post watch_legislation_url(@legislation)
    end
    assert_redirected_to legislation_path(@legislation)
  end

  test "unwatch removes legislation from watchlists" do
    watchlist = Watchlist.default_for(@user)
    watchlist.watchlist_items.create!(legislation: @legislation, item_type: "specific_legislation")

    assert_difference "WatchlistItem.count", -1 do
      delete unwatch_legislation_url(@legislation)
    end
  end

  test "show displays watchlist items" do
    watchlist = Watchlist.default_for(@user)
    watchlist.watchlist_items.create!(legislation: @legislation, item_type: "specific_legislation")

    get watchlist_url(watchlist)
    assert_response :success
  end
end
