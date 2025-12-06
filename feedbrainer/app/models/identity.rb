class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  # Check if the OAuth token has expired
  def expired?
    expires_at && expires_at < Time.current
  end

  # Check if token needs refresh (expired or expiring soon)
  def needs_refresh?
    expired? || (expires_at && expires_at < 1.hour.from_now)
  end

  # Get a fresh access token (refresh if needed)
  def fresh_access_token
    # TODO: Implement token refresh logic
    # For now, just return the current token
    access_token
  end
end
