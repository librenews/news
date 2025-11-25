class Source < ApplicationRecord
  has_many :user_sources, dependent: :destroy
  has_many :users, through: :user_sources
  has_many :posts, dependent: :destroy

  validates :atproto_did, uniqueness: true, allow_nil: true
end
