class User < ApplicationRecord
  has_many :user_sources, dependent: :destroy
  has_many :sources, through: :user_sources
  has_many :direct_follow_sources, -> { where(user_sources: { relationship_type: :direct_follow }) }, through: :user_sources, source: :source
  has_many :friend_of_friend_sources, -> { where(user_sources: { relationship_type: :friend_of_friend }) }, through: :user_sources, source: :source
  
  # OAuth identities (Bluesky, Mastodon, etc.)
  has_many :identities, dependent: :destroy
  has_many :chats, dependent: :destroy

  validates :atproto_did, uniqueness: true, allow_nil: true
  validates :email, uniqueness: true, allow_nil: true

  after_create :enqueue_follows_sync, if: -> { atproto_did.present? }

  # OAuth-only users don't need email/password
  def oauth_only?
    identities.exists?
  end

  # Bluesky-specific helpers
  def bluesky_identity
    identities.find_by(provider: 'bluesky')
  end

  def bluesky_access_token
    bluesky_identity&.access_token
  end

  def bluesky_connected?
    bluesky_identity.present? && bluesky_connected_at.present?
  end

  private

  def enqueue_follows_sync
    SyncUserFollowsJob.perform_later(id)
  end
end
