class IngestPostJob < ApplicationJob
  queue_as :default

  def perform(post_data, links)
    return if links.empty?

    # 1. Fetch each link
    links.each do |link|
      fetch_result = FetchLinkService.call(link)
      unless fetch_result[:success]
        Rails.logger.warn("IngestPostJob: Failed to fetch #{link}: #{fetch_result[:error]}")
        next
      end

      # 2. Check if it's a news article and extract metadata
      news_result = NewsDetectionService.call(fetch_result[:html_content], link)
      unless news_result[:is_news_article]
        Rails.logger.info("IngestPostJob: #{link} is not a news article")
        next
      end

      # 3. It IS a news article! Now we persist everything.
      
      # Find or Create Source
      did = post_data.dig("did")
      source = Source.find_or_initialize_by(atproto_did: did)
      if source.new_record?
        source.save!
        SyncSourceProfileJob.perform_later(source.id)
      end

      # Find or Create Article
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

      # Create Post
      # We need to reconstruct the Post record from the raw data
      # The raw data structure from Skybeam might be slightly different than what we stored before
      # Skybeam sends the whole event.
      
      # Check if post already exists to avoid duplicates
      rkey = post_data.dig("commit", "rkey") 
      # Note: rkey isn't directly in the top level usually, it's part of the URI or we need to extract it.
      # Actually, Skybeam event structure: %{"commit" => ..., "did" => ...}
      # The "commit" map usually contains "rkey" if we parsed it that way, or we extract from URI.
      # Let's assume we can find the URI.
      
      uri = post_data.dig("commit", "record", "uri") || 
            "at://#{did}/#{post_data.dig('commit', 'collection')}/#{extract_rkey(post_data)}"
      
      Rails.logger.info("IngestPostJob: Generated URI: #{uri}")
            
      post = Post.find_or_initialize_by(uri: uri)
      if post.new_record?
        post.source = source
        post.payload = post_data # Save the raw data
        post.published_at = post_data.dig("commit", "record", "createdAt")
        if post.save
          Rails.logger.info("IngestPostJob: Created Post #{post.id}")
        else
          Rails.logger.error("IngestPostJob: Failed to save Post: #{post.errors.full_messages.join(', ')}")
        end
      else
        Rails.logger.info("IngestPostJob: Post already exists: #{post.id}")
      end

      # Link Article to Post
      ap = ArticlePost.find_or_create_by!(post: post, article: article)
      Rails.logger.info("IngestPostJob: Linked Article #{article.id} to Post #{post.id} (ArticlePost #{ap.id})")
      
      Rails.logger.info("IngestPostJob: Successfully ingested article #{article.id} from post #{post.id}")
    end
  end

  private

  def extract_rkey(post_data)
    # Fallback if URI is not present
    # This depends on how Skybeam passes data. 
    # If Skybeam passes the full Jetstream event, it has 'commit' -> 'rkey' usually?
    # Actually Jetstream events have 'commit' -> 'rkey'.
    post_data.dig("commit", "rkey")
  end
end
