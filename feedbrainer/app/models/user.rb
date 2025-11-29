class User < ApplicationRecord
  has_many :user_sources, dependent: :destroy
  has_many :sources, through: :user_sources

  validates :atproto_did, uniqueness: true, allow_nil: true

  after_create :enqueue_follows_sync, if: -> { atproto_did.present? }

  private

  def enqueue_follows_sync
    SyncUserFollowsJob.perform_later(id)
  end
end
