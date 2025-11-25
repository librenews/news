class ProcessPostJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    post = Post.find(post_id)
    
    # 1. Detect links from facets
    links = LinkDetectionService.call(post)
    
    return if links.empty?
    
    # 2. Fetch each link
    links.each do |link|
      fetch_result = FetchLinkService.call(link)
      next unless fetch_result[:success]
      
      # 3. Check if it's a news article and extract metadata
      news_result = NewsDetectionService.call(fetch_result[:html_content], link)
      next unless news_result[:is_news_article]
      
      # 4. Create Article and ArticlePost
      article = Article.create!(
        title: news_result[:title] || link,
        url: link,
        html_content: fetch_result[:html_content],
        jsonld_data: news_result[:jsonld_data], # Array of JSON-LD objects
        published_at: news_result[:published_at],
        author: news_result[:author],
        description: news_result[:description],
        image_url: news_result[:image_url],
        body_text: news_result[:body_text]
      )
      
      ArticlePost.create!(post: post, article: article)
    end
  end
end

