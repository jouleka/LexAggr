class LegislationVersion < ApplicationRecord
  belongs_to :legislation
  has_many :document_nodes, dependent: :destroy

  validates :version_uri, presence: true, uniqueness: true

  scope :in_force_on, ->(date) {
    where("valid_from <= ? AND (valid_to IS NULL OR valid_to >= ?)", date, date)
  }
  scope :current, -> { where(valid_to: nil) }
  scope :in_language, ->(lang) { where(language: lang) }
end
