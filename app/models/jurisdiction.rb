class Jurisdiction < ApplicationRecord
  TYPES = %w[supranational country].freeze

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :jurisdiction_type, inclusion: { in: TYPES }, allow_nil: true

  has_many :legislations, dependent: :restrict_with_error
  has_many :ingestion_logs, dependent: :restrict_with_error
end
