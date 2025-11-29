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
    facets = @post_data.dig("commit", "record", "facets") || []
    
    facets.each do |facet|
      features = facet["features"] || []
      features.each do |feature|
        if feature["$type"] == "app.bsky.richtext.facet#link"
          links << feature["uri"]
        end
      end
    end
    
    links.uniq
  end
end

