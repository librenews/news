class Post < ApplicationRecord
  belongs_to :source
  has_many :article_posts, dependent: :destroy
  has_many :articles, through: :article_posts

  validates :uri, presence: true, uniqueness: true
  validates :published_at, presence: true

  alias_attribute :payload, :post

  def body
    payload&.dig("record", "text")
  end
end
