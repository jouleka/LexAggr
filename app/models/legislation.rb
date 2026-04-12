class Legislation < ApplicationRecord
  belongs_to :jurisdiction
  has_many :legislation_versions, dependent: :destroy

  validates :frbr_uri, presence: true, uniqueness: true
  validates :title, presence: true

  scope :in_force, -> { where(status: "in_force") }
  scope :by_type, ->(type) { where(legislation_type: type) }
  scope :by_year, ->(year) { where(year: year) }
end
