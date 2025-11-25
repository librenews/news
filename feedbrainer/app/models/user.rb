class User < ApplicationRecord
  has_many :user_sources, dependent: :destroy
  has_many :sources, through: :user_sources

  validates :atproto_did, uniqueness: true, allow_nil: true
end
