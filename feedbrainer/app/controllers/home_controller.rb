class HomeController < ApplicationController
  def index
    # Get most popular articles ranked by number of shares (article_posts count)
    # Use a subquery to count shares and order by that count
    @articles = Article
      .joins(:article_posts)
      .group('articles.id')
      .select('articles.*, COUNT(article_posts.id) as share_count')
      .order('COUNT(article_posts.id) DESC, articles.created_at DESC')
      .limit(50)
      .includes(:posts => :source)
  end
end
