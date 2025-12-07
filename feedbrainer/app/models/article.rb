class Article < ApplicationRecord
  has_many :article_posts, dependent: :destroy
  has_many :posts, through: :article_posts
  has_many :article_chunks, dependent: :destroy
  has_many :article_entities, dependent: :destroy
  has_many :entities, through: :article_entities

  validates :title, presence: true
  validates :url, presence: true, uniqueness: true

  # Virtual attribute for share count from SQL query
  attr_accessor :share_count
  
  # Virtual attributes for caching optimization
  attr_accessor :distinct_sources, :distinct_source_count

  after_create_commit :enqueue_embedding_processing

  def clean_text!
    cleaned = ArticleTextCleaningService.call(self)
    update_column(:cleaned_text, cleaned) if cleaned.present?
    cleaned
  end

  scope :ranked, ->(limit: 50) {
    gravity = 1.8
    joins(:article_posts)
      .where("articles.created_at > ?", 7.days.ago)
      .group("articles.id")
      .select("articles.*, COUNT(article_posts.id) AS share_count")
      .order(Arel.sql("COUNT(article_posts.id) / POWER((EXTRACT(EPOCH FROM (NOW() - articles.created_at)) / 3600) + 2, #{gravity}) DESC"))
      .limit(limit)
      .preload(posts: :source)
  }

  private

  def enqueue_embedding_processing
    ProcessArticleEmbeddingsJob.perform_later(id)
  end
end
