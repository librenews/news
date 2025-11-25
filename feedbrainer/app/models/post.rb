class Post < ApplicationRecord
  belongs_to :source
  has_many :article_posts, dependent: :destroy
  has_many :articles, through: :article_posts
end
