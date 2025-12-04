class UserSource < ApplicationRecord
  belongs_to :user
  belongs_to :source

  enum :relationship_type, { direct_follow: 1, friend_of_friend: 2 }

  # A user can only have one relationship with a source (either direct_follow or friend_of_friend)
  # Direct follow takes precedence - if user directly follows a source, we don't create friend_of_friend
  validates :user_id, uniqueness: { scope: :source_id }
end

