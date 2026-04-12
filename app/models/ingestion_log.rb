class IngestionLog < ApplicationRecord
  belongs_to :jurisdiction

  STATUSES = %w[running completed failed].freeze

  validates :jurisdiction, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  def self.latest_for(jurisdiction, source_name)
    where(jurisdiction: jurisdiction, source_name: source_name).order(created_at: :desc).first
  end

  def mark_completed!(documents_processed:)
    update!(status: "completed", documents_processed: documents_processed)
  end

  def mark_failed!(error_message)
    update!(status: "failed", error_message: error_message)
  end
end
