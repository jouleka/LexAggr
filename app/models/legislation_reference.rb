class LegislationReference < ApplicationRecord
  REFERENCE_TYPES = %w[cites amends repeals implements based_on].freeze

  belongs_to :source_legislation, class_name: "Legislation"
  belongs_to :target_legislation, class_name: "Legislation"

  validates :reference_type, presence: true, inclusion: { in: REFERENCE_TYPES }
  validates :target_legislation_id, uniqueness: { scope: [ :source_legislation_id, :reference_type ] }

  scope :cites, -> { where(reference_type: "cites") }
  scope :amends, -> { where(reference_type: "amends") }
  scope :repeals, -> { where(reference_type: "repeals") }
  scope :implements, -> { where(reference_type: "implements") }
end
