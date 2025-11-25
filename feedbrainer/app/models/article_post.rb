class ArticlePost < ApplicationRecord
  belongs_to :article
  belongs_to :post

  validates :article_id, uniqueness: { scope: :post_id }
end

