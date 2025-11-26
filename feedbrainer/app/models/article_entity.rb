class ArticleEntity < ApplicationRecord
  belongs_to :article
  belongs_to :entity

  validates :article_id, uniqueness: { scope: :entity_id }
  validates :frequency, presence: true, numericality: { greater_than: 0 }
end

