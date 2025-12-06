class HomeController < ApplicationController
  def index
    # Hacker News ranking algorithm: (p - 1) / (t + 2)^1.8
    # We use share_count as 'p' and hours since creation as 't'
    gravity = 1.8
    
    # Cache key includes format and article timestamps for auto-invalidation
    cache_key = "home_index_#{request.format.symbol}_#{Article.maximum(:updated_at)&.to_i || 0}"
    
    @articles = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      articles = Article
        .joins(:article_posts)
        .where("articles.created_at > ?", 7.days.ago)
        .group("articles.id")
        .select("articles.*, COUNT(article_posts.id) AS share_count")
        .order(Arel.sql("COUNT(article_posts.id) / POWER((EXTRACT(EPOCH FROM (NOW() - articles.created_at)) / 3600) + 2, #{gravity}) DESC"))
        .limit(50)
        .includes(posts: :source)
        .to_a
      
      # Pre-calculate distinct sources for each article
      articles.each do |article|
        article.distinct_sources = article.posts.group_by(&:source_id).values.map(&:first).first(20)
        article.distinct_source_count = article.posts.map(&:source_id).uniq.count
      end
      
      articles
    end
    
    # Ensure virtual attributes are present (in case of cache serialization issues)
    @articles.each do |article|
      if article.distinct_sources.nil?
        article.distinct_sources = article.posts.group_by(&:source_id).values.map(&:first).first(20)
        article.distinct_source_count = article.posts.map(&:source_id).uniq.count
      end
    end

    # Batch load all sources that might be referenced in reposts
    # This must be done AFTER cache fetch so it runs on cache hits too
    all_post_dids = @articles.flat_map(&:posts).flat_map do |post|
      dids = []
      # Get the repost subject DID if it exists
      subject_uri = post.post&.dig("commit", "record", "subject", "uri")
      if subject_uri.present?
        uri_match = subject_uri.match(/\Aat:\/\/([^\/]+)\/([^\/]+)\/([^\/]+)\z/)
        dids << uri_match[1] if uri_match
      end
      dids
    end.compact.uniq
    
    # Preload all these sources into memory
    @preloaded_sources = Source.where(atproto_did: all_post_dids).index_by(&:atproto_did)
    
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
  
  # Helper method to get preloaded source
  helper_method :preloaded_source
  
  def preloaded_source(did)
    @preloaded_sources&.dig(did)
  end
end
