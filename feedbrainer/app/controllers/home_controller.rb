class HomeController < ApplicationController
  def index
    @articles = fetch_ranked_articles("home_index")
    
    respond_to do |format|
      format.html # renders index.html.erb
      format.json { render_json_articles }
      format.rss { render layout: false }
    end
  end

  def network
    unless user_signed_in?
      redirect_to login_path, alert: "Please sign in to view your network feed."
      return
    end

    # Get network source IDs for filtering
    network_source_ids = current_user.sources.pluck(:id)

    # Filter articles by followed sources using joins
    # This ensures COUNT(article_posts.id) only counts posts from network sources
    scope = Article.joins(posts: :source).where(sources: { id: network_source_ids })

    @articles = fetch_ranked_articles("network_index_#{current_user.id}", scope, network_source_ids)

    render :index
  end

  private

  def fetch_ranked_articles(cache_key_prefix, scope = Article.all, filter_source_ids = nil)
    # Hacker News ranking algorithm: (p - 1) / (t + 2)^1.8
    gravity = 1.8
    
    # Cache key includes format and article timestamps for auto-invalidation
    cache_key = "#{cache_key_prefix}_#{request.format.symbol}_#{Article.maximum(:updated_at)&.to_i || 0}"
    
    articles = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      results = scope
        .joins(:article_posts)
        .where("articles.created_at > ?", 7.days.ago)
        .group("articles.id")
        .select("articles.*, COUNT(article_posts.id) AS share_count")
        .order(Arel.sql("COUNT(article_posts.id) / POWER((EXTRACT(EPOCH FROM (NOW() - articles.created_at)) / 3600) + 2, #{gravity}) DESC"))
        .limit(50)
        .preload(posts: :source) # Use preload to avoid affecting the main query's GROUP BY
        .to_a
      
      # Pre-calculate distinct sources for each article
      results.each do |article|
        posts = article.posts
        
        # Filter sources if a filter is provided (e.g. for network feed)
        if filter_source_ids
          posts = posts.select { |p| filter_source_ids.include?(p.source_id) }
        end

        article.distinct_sources = posts.group_by(&:source_id).values.map(&:first).first(20)
        article.distinct_source_count = posts.map(&:source_id).uniq.count
      end
      
      results
    end
    
    # Ensure virtual attributes are present (in case of cache serialization issues)
    articles.each do |article|
      if article.distinct_sources.nil?
        article.distinct_sources = article.posts.group_by(&:source_id).values.map(&:first).first(20)
        article.distinct_source_count = article.posts.map(&:source_id).uniq.count
      end
    end

    # Batch load all sources that might be referenced in reposts
    preload_repost_sources(articles)
    
    # Enable conditional GET for client-side caching
    fresh_when(last_modified: Article.maximum(:updated_at), etag: cache_key, public: true)
    
    articles
  end

  def preload_repost_sources(articles)
    all_post_dids = articles.flat_map(&:posts).flat_map do |post|
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
  end

  def render_json_articles
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
  
  # Helper method to get preloaded source
  helper_method :preloaded_source
  
  def preloaded_source(did)
    @preloaded_sources&.dig(did)
  end
end
