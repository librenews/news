# script/test_link_detection.rb
require_relative '../config/environment'

# Mock Post object
class MockPost
  attr_accessor :post
  def initialize(json)
    @post = json
  end
end

puts "--- Testing LinkDetectionService ---"

# Case 1: Text Link (Facet) - Should work
post_with_facet = {
  "commit" => {
    "record" => {
      "text" => "Check this out: https://example.com",
      "facets" => [
        {
          "features" => [
            {
              "$type" => "app.bsky.richtext.facet#link",
              "uri" => "https://example.com"
            }
          ]
        }
      ]
    }
  }
}
links = LinkDetectionService.call(MockPost.new(post_with_facet))
puts "Case 1 (Facet): #{links.inspect} (Expected: ['https://example.com'])"

# Case 2: Link Card (Embed External) - Currently fails?
post_with_embed_external = {
  "commit" => {
    "record" => {
      "text" => "Check this link card",
      "embed" => {
        "$type" => "app.bsky.embed.external",
        "external" => {
          "uri" => "https://example.org/card",
          "title" => "Example Card",
          "description" => "Description"
        }
      }
    }
  }
}
links = LinkDetectionService.call(MockPost.new(post_with_embed_external))
puts "Case 2 (Embed External): #{links.inspect} (Expected: ['https://example.org/card'])"

# Case 3: Repost (Embed Record) - Currently fails?
post_with_embed_record = {
  "commit" => {
    "record" => {
      "text" => "", # Reposts usually have empty text
      "embed" => {
        "$type" => "app.bsky.embed.record",
        "record" => {
          "uri" => "at://did:plc:123/app.bsky.feed.post/456",
          "cid" => "bafy..."
        }
      }
    }
  }
}
# Mock BlueskyClient
class BlueskyClient
  def self.get_posts(uris)
    # Return a mock response for the test URI
    if uris.include?("at://did:plc:123/app.bsky.feed.post/456")
      {
        success: true,
        posts: [
          {
            "record" => {
              "text" => "Original post text",
              "facets" => [
                {
                  "features" => [
                    {
                      "$type" => "app.bsky.richtext.facet#link",
                      "uri" => "https://original-post.com"
                    }
                  ]
                }
              ]
            }
          }
        ]
      }
    else
      { success: false }
    end
  end
end

links = LinkDetectionService.call(MockPost.new(post_with_embed_record))
puts "Case 3 (Embed Record): #{links.inspect} (Expected: ['https://original-post.com'])"
