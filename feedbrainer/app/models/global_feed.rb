class GlobalFeed < ApplicationRecord
  has_many :chat_contexts, as: :context

  def posts
    Post.order(published_at: :desc).limit(100)
  end
end
