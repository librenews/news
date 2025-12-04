class User < ApplicationRecord
  has_many :user_sources, dependent: :destroy
  has_many :sources, through: :user_sources
  has_many :direct_follow_sources, -> { where(user_sources: { relationship_type: :direct_follow }) }, through: :user_sources, source: :source
  has_many :friend_of_friend_sources, -> { where(user_sources: { relationship_type: :friend_of_friend }) }, through: :user_sources, source: :source

  validates :atproto_did, uniqueness: true, allow_nil: true

  after_create :enqueue_follows_sync, if: -> { atproto_did.present? }

  private

  def enqueue_follows_sync
    SyncUserFollowsJob.perform_later(id)
  end
end
