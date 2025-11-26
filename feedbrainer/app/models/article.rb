class Article < ApplicationRecord
  has_many :article_posts, dependent: :destroy
  has_many :posts, through: :article_posts
  has_many :article_chunks, dependent: :destroy
  has_many :article_entities, dependent: :destroy
  has_many :entities, through: :article_entities

  validates :title, presence: true
  validates :url, presence: true, uniqueness: true

  after_create_commit :enqueue_embedding_processing

  def clean_text!
    cleaned = ArticleTextCleaningService.call(self)
    update_column(:cleaned_text, cleaned) if cleaned.present?
    cleaned
  end

  private

  def enqueue_embedding_processing
    ProcessArticleEmbeddingsJob.perform_later(id)
  end
end
