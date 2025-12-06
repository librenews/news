class HomeController < ApplicationController
  def index
    # Hacker News ranking algorithm: (p - 1) / (t + 2)^1.8
    # We use share_count as 'p' and hours since creation as 't'
    gravity = 1.8
    
    # Cache key includes format and article timestamps for auto-invalidation
    cache_key = "home_index_#{request.format.symbol}_#{Article.maximum(:updated_at)&.to_i || 0}"
    
    @articles = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      Article
        .joins(:article_posts)
        .where("articles.created_at > ?", 7.days.ago)
        .group("articles.id")
        .select("articles.*, COUNT(article_posts.id) AS share_count")
        .order(Arel.sql("COUNT(article_posts.id) / POWER((EXTRACT(EPOCH FROM (NOW() - articles.created_at)) / 3600) + 2, #{gravity}) DESC"))
        .limit(50)
        .includes(posts: :source)
        .to_a
    end
    
    # Enable conditional GET for client-side caching
    fresh_when(last_modified: Article.maximum(:updated_at), etag: cache_key, public: true)
    
    respond_to do |format|
      format.html # renders index.html.erb
      
      format.json do
        render json: @articles.as_json(
          only: [:id, :title, :url, :description, :author, :published_at, :created_at, :image_url],
          methods: [:share_count],
          include: {
            posts: {
              only: [:id, :uri, :published_at],
              include: {
                source: {
                  only: [:id, :atproto_did],
                  methods: [:handle, :display_name, :avatar]
                }
              }
            }
          }
        )
      end
      
      format.rss { render layout: false }
    end
  end
end
