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
      unless fetch_result[:success]
        Rails.logger.warn("ProcessPostJob: Failed to fetch #{link}: #{fetch_result[:error]}")
        next
      end
      
      # 3. Check if it's a news article and extract metadata
      news_result = NewsDetectionService.call(fetch_result[:html_content], link)
      unless news_result[:is_news_article]
        Rails.logger.info("ProcessPostJob: #{link} is not a news article")
        next
      end
      
      # 4. Find or Create Article
      article = Article.find_or_initialize_by(url: link)
      
      if article.new_record?
        article.assign_attributes(
          title: news_result[:title] || link,
          html_content: fetch_result[:html_content],
          jsonld_data: news_result[:jsonld_data],
          published_at: news_result[:published_at],
          author: news_result[:author],
          description: news_result[:description],
          image_url: news_result[:image_url],
          body_text: news_result[:body_text]
        )
        article.save!
      end
      
      ArticlePost.find_or_create_by!(post: post, article: article)
    end
  end
end

