class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :watchlists, dependent: :destroy

  ALERT_FREQUENCIES = %w[daily weekly none].freeze
  validates :alert_frequency, inclusion: { in: ALERT_FREQUENCIES }

  scope :wants_alerts, -> { where(alert_email_enabled: true).where.not(alert_frequency: "none") }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
