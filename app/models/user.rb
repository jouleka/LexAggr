class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :watchlists, dependent: :destroy

  ALERT_FREQUENCIES = %w[daily weekly none].freeze
  validates :alert_frequency, inclusion: { in: ALERT_FREQUENCIES }

  scope :wants_alerts, -> { where(alert_email_enabled: true).where.not(alert_frequency: "none") }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def self.authenticate_api_token(token)
    return unless token&.match?(/\A[0-9a-f]{64}\z/)

    find_by(api_token_digest: Digest::SHA256.hexdigest(token))
  end

  # Return the raw token exactly once and store only its digest.
  def rotate_api_token!
    token = SecureRandom.hex(32)
    update!(api_token_digest: Digest::SHA256.hexdigest(token))
    token
  end
end
