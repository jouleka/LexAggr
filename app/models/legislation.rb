class Legislation < ApplicationRecord
  include PgSearch::Model

  belongs_to :jurisdiction
  has_many :legislation_versions, dependent: :destroy
  has_many :watchlist_items, dependent: :destroy

  pg_search_scope :search_full_text,
    against: :title,
    using: {
      tsearch: {
        tsvector_column: "searchable",
        prefix: true
      },
      trigram: {
        word_similarity: true
      }
    }

  LEGISLATION_TYPES = %w[regulation directive decision delegated_directive delegated_regulation implementing_regulation act other].freeze
  STATUSES = %w[in_force repealed pending].freeze

  validates :frbr_uri, presence: true, uniqueness: true
  validates :title, presence: true
  validates :legislation_type, inclusion: { in: LEGISLATION_TYPES }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  scope :in_force, -> { where(status: "in_force") }
  scope :by_type, ->(type) { where(legislation_type: type) }
  scope :by_year, ->(year) { where(year: year) }
end
