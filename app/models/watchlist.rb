class Watchlist < ApplicationRecord
  belongs_to :user
  has_many :watchlist_items, dependent: :destroy
  has_many :legislations, through: :watchlist_items

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id }

  def self.default_for(user)
    user.watchlists.find_or_create_by!(name: "My Watchlist")
  end
end
