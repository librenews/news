class HomeController < ApplicationController
  def index
    # Hacker News ranking algorithm: (p - 1) / (t + 2)^1.8
    # We use share_count as 'p' and hours since creation as 't'
    gravity = 1.8
    
    @articles = Article
      .joins(:article_posts)
      .where("articles.created_at > ?", 7.days.ago)
      .group("articles.id")
      .select("articles.*, COUNT(article_posts.id) AS share_count")
      .order(Arel.sql("COUNT(article_posts.id) / POWER((EXTRACT(EPOCH FROM (NOW() - articles.created_at)) / 3600) + 2, #{gravity}) DESC"))
      .limit(50)
      .includes(posts: :source)
  end
end

