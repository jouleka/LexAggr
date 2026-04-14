class WatchlistItem < ApplicationRecord
  ITEM_TYPES = %w[specific_legislation jurisdiction_filter].freeze

  belongs_to :watchlist
  belongs_to :legislation, optional: true
  belongs_to :jurisdiction, optional: true

  validates :item_type, presence: true, inclusion: { in: ITEM_TYPES }
  validates :legislation_id, uniqueness: { scope: :watchlist_id }, allow_nil: true

  scope :specific, -> { where(item_type: "specific_legislation") }
  scope :filters, -> { where(item_type: "jurisdiction_filter") }
end
