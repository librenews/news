class HomeController < ApplicationController
  def index
    # Most popular articles ranked by number of shares (ArticlePosts)
    @articles = Article
      .joins(:article_posts)
      .group("articles.id")
      .select("articles.*, COUNT(article_posts.id) AS share_count")
      .order("COUNT(article_posts.id) DESC, articles.created_at DESC")
      .limit(50)
      .includes(posts: :source)
  end
end

