class ArticleChunk < ApplicationRecord
  belongs_to :article

  validates :chunk_index, presence: true, uniqueness: { scope: :article_id }
  validates :text, presence: true
  validates :token_count, presence: true, numericality: { greater_than: 0 }
  validates :checksum, presence: true
end

