class DigestMailer < ApplicationMailer
  default from: "FeedBrainer <no-reply@open.news>"

  def daily_digest(user)
    @user = user
    
    # Logic similar to HomeController#network but for email
    # 1. Get network source IDs
    network_source_ids = user.sources.pluck(:id)
    
    # 2. Filter articles by network sources
    scope = Article.joins(posts: :source).where(sources: { id: network_source_ids })
    
    # 3. Rank and limit to top 10
    @articles = scope.ranked(limit: 10).to_a
    
    # 4. Process articles for display (distinct sources)
    @articles.each do |article|
      posts = article.posts
      # Filter to only show network sources
      posts = posts.select { |p| network_source_ids.include?(p.source_id) }
      
      article.distinct_sources = posts.group_by(&:source_id).values.map(&:first).first(5)
      article.distinct_source_count = posts.map(&:source_id).uniq.count
    end

    # Fallback to global top stories if network is empty
    if @articles.empty?
      @articles = Article.ranked(limit: 10).to_a
      @is_global_fallback = true
    end

    return if @articles.empty?

    mail(to: @user.email, subject: "Your Daily Digest - open.news")
  end
end
