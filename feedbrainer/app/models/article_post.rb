class ArticlePost < ApplicationRecord
  belongs_to :article, touch: true
  belongs_to :post

  validates :article_id, uniqueness: { scope: :post_id }
end

