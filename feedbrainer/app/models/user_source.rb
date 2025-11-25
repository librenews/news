class UserSource < ApplicationRecord
  belongs_to :user
  belongs_to :source

  validates :user_id, uniqueness: { scope: :source_id }
end

