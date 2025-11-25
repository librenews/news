class Post < ApplicationRecord
  belongs_to :source
  has_many :article_posts, dependent: :destroy
  has_many :articles, through: :article_posts

  after_create_commit :enqueue_processing

  private

  def enqueue_processing
    ProcessPostJob.perform_later(id)
  end
end
