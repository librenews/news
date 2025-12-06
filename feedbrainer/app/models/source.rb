class Source < ApplicationRecord
  has_many :user_sources, dependent: :destroy
  has_many :users, through: :user_sources
  has_many :posts, dependent: :destroy

  validates :atproto_did, uniqueness: true, allow_nil: true

  def handle
    profile&.dig("handle") || atproto_did
  end

  def display_name
    profile&.dig("displayName") || handle
  end

  def avatar
    profile&.dig("avatar")
  end
end
