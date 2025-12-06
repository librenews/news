class IngestPostJob < ApplicationJob
  queue_as :default
  
  # Retry on transient errors
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(post_data, links)
    return if links.empty?
    
    # Validate required data
    did = post_data.dig("did")
    unless did
      Rails.logger.error("IngestPostJob: Missing 'did' in post_data")
      return
    end

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
      
      # Extract URI - prefer from record, fallback to constructing from components
      uri = post_data.dig("commit", "record", "uri")
      unless uri
        collection = post_data.dig("commit", "collection")
        rkey = extract_rkey(post_data)
        if collection && rkey && did
          uri = "at://#{did}/#{collection}/#{rkey}"
        else
          Rails.logger.error("IngestPostJob: Cannot construct URI - missing required fields (did: #{did.present?}, collection: #{collection.present?}, rkey: #{rkey.present?})")
          next
        end
      end
      
      # Parse published_at from ISO string
      created_at_str = post_data.dig("commit", "record", "createdAt")
      published_at = nil
      if created_at_str
        begin
          published_at = Time.parse(created_at_str)
        rescue => e
          Rails.logger.warn("IngestPostJob: Failed to parse createdAt '#{created_at_str}': #{e.message}")
          # Fallback to current time if parsing fails
          published_at = Time.current
        end
      else
        Rails.logger.warn("IngestPostJob: No createdAt found, using current time")
        published_at = Time.current
      end
      
      Rails.logger.debug("IngestPostJob: Generated URI: #{uri}, published_at: #{published_at}")
            
      post = Post.find_or_initialize_by(uri: uri)
      if post.new_record?
        post.source = source
        post.payload = post_data # Save the raw data
        post.published_at = published_at
        if post.save
          Rails.logger.info("IngestPostJob: Created Post #{post.id}")
        else
          Rails.logger.error("IngestPostJob: Failed to save Post: #{post.errors.full_messages.join(', ')}")
          next # Skip this link if we can't save the post
        end
      else
        Rails.logger.debug("IngestPostJob: Post already exists: #{post.id}")
      end

      # Link Article to Post
      ap = ArticlePost.find_or_create_by!(post: post, article: article)
      Rails.logger.info("IngestPostJob: Linked Article #{article.id} to Post #{post.id} (ArticlePost #{ap.id})")
      
      Rails.logger.info("IngestPostJob: Successfully ingested article #{article.id} from post #{post.id}")
    end
  rescue => e
    Rails.logger.error("IngestPostJob: Unexpected error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    raise # Re-raise to trigger retry mechanism
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
