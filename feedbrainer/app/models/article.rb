class Article < ApplicationRecord
  has_many :article_posts, dependent: :destroy
  has_many :posts, through: :article_posts

  validates :title, presence: true
  validates :url, presence: true, uniqueness: true
end
