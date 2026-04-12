class Legislation < ApplicationRecord
  include PgSearch::Model

  belongs_to :jurisdiction
  has_many :legislation_versions, dependent: :destroy

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

  validates :frbr_uri, presence: true, uniqueness: true
  validates :title, presence: true

  scope :in_force, -> { where(status: "in_force") }
  scope :by_type, ->(type) { where(legislation_type: type) }
  scope :by_year, ->(year) { where(year: year) }
end
