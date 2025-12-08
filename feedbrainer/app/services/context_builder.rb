class ContextBuilder
  def initialize(chat)
    @chat = chat
  end

  def build
    {
      posts: gather_posts,
      # articles: gather_articles (future)
    }
  end

  private

  def gather_posts
    @chat.all_posts.map do |post|
      {
        id: post.id,
        content: post.body,
        source: post.source.handle,
        posted_at: post.published_at
      }
    end
  end
end
