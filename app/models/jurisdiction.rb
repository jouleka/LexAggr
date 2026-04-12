class Jurisdiction < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  has_many :legislations, dependent: :destroy
  has_many :ingestion_logs, dependent: :destroy
end
