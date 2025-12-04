class LinkDetectionService
  def self.call(post)
    new(post).call
  end

  def initialize(post)
    @post = post
    @post_data = post.post
  end

  def call
    links = []
    
    # Bluesky stores links in facets array
    # Each facet has a type and features array
    # Link facets have type "app.bsky.richtext.facet#link"
    # Check if it's a pure repost
    collection = @post_data.dig("commit", "collection")
    if collection == "app.bsky.feed.repost"
      subject_uri = @post_data.dig("commit", "record", "subject", "uri")
      if subject_uri
        extract_links_from_original_post(subject_uri, links)
      end
      return links.uniq
    end

    facets = @post_data.dig("commit", "record", "facets") || []
    
    facets.each do |facet|
      features = facet["features"] || []
      features.each do |feature|
        if feature["$type"] == "app.bsky.richtext.facet#link"
          links << feature["uri"]
        end
      end
    end

    # Check for external embeds (link cards)
    embed = @post_data.dig("commit", "record", "embed")
    if embed
      case embed["$type"]
      when "app.bsky.embed.external"
        if embed.dig("external", "uri").present?
          links << embed.dig("external", "uri")
        end
      when "app.bsky.embed.record"
        # Repost or Quote Post - fetch original post
        if embed.dig("record", "uri").present?
          original_uri = embed.dig("record", "uri")
          extract_links_from_original_post(original_uri, links)
        end
      when "app.bsky.embed.recordWithMedia"
        # Quote Post with Media
        if embed.dig("record", "record", "uri").present?
          original_uri = embed.dig("record", "record", "uri")
          extract_links_from_original_post(original_uri, links)
        end
      end
    end
    
    # Fallback: extract URLs from post text if no facets found
    if links.empty?
      text = @post_data.dig("commit", "record", "text") || ""
      # Extract URLs from text (simple regex)
      text.scan(%r{https?://[^\s\)]+}) do |url|
        # Clean up trailing punctuation
        url = url.gsub(/[.,;:!?]+$/, "")
        links << url
      end
    end
    
    links.uniq
  end

  private

  def extract_links_from_original_post(uri, links)
    # Fetch original post from Bluesky
    result = BlueskyClient.get_posts(uri)
    return unless result[:success] && result[:posts].any?

    post_view = result[:posts].first
    record = post_view["record"]
    return unless record

    # Extract links from facets of original post
    facets = record["facets"] || []
    facets.each do |facet|
      features = facet["features"] || []
      features.each do |feature|
        if feature["$type"] == "app.bsky.richtext.facet#link"
          links << feature["uri"]
        end
      end
    end

    # Extract links from external embed of original post
    embed = record["embed"]
    if embed && embed["$type"] == "app.bsky.embed.external"
      if embed.dig("external", "uri").present?
        links << embed.dig("external", "uri")
      end
    end
  end
end

