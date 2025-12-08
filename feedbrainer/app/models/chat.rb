class Chat < ApplicationRecord
  belongs_to :user
  has_many :chat_contexts, dependent: :destroy
  has_many :chat_messages, dependent: :destroy

  # Helper to get all posts from all contexts
  def all_posts
    chat_contexts.includes(:context).flat_map { |cc| cc.context.posts }
  end
end
