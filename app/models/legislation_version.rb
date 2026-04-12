class LegislationVersion < ApplicationRecord
  belongs_to :legislation
  has_one :content, class_name: "LegislationVersionContent", dependent: :destroy
  has_many :document_nodes, dependent: :destroy

  VERSION_TYPES = %w[original consolidation amendment].freeze

  validates :version_uri, presence: true, uniqueness: true
  validates :version_type, inclusion: { in: VERSION_TYPES }, allow_nil: true

  scope :in_force_on, ->(date) {
    where("(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)", date, date)
  }
  scope :current, -> { where(valid_to: nil) }
  scope :in_language, ->(lang) { where(language: lang) }
end
