#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check if a link from a specific DID was captured
# Usage: rails runner script/check_link_capture.rb [DID]

require_relative "../config/environment"

did = ARGV[0] || "did:plc:iq44hcebgqaom6jvtcd3ln73"

puts "Checking for link capture from DID: #{did}"
puts "=" * 80

# Find the source
source = Source.find_by(atproto_did: did)
unless source
  puts "❌ No source found with DID: #{did}"
  puts "\nAvailable sources:"
  Source.all.each do |s|
    puts "  - #{s.atproto_did} (ID: #{s.id})"
  end
  exit 1
end

puts "✅ Found source: #{source.atproto_did} (ID: #{source.id})"
puts

# Find posts from this source
posts = source.posts.order(created_at: :desc)
puts "📝 Found #{posts.count} post(s) from this source"
puts

if posts.empty?
  puts "No posts found. The post may not have been captured yet."
  exit 0
end

# Check each post for links and articles
posts.each_with_index do |post, index|
  puts "-" * 80
  puts "Post ##{index + 1} (ID: #{post.id}, Created: #{post.created_at})"
  
  # Extract links from the post
  links = LinkDetectionService.call(post)
  
  # Also check for links in embed.external.uri (common for link cards)
  embed = post.post.dig("record", "embed")
  if embed && embed["$type"] == "app.bsky.embed.external"
    external_uri = embed.dig("external", "uri")
    links << external_uri if external_uri
  end
  
  if links.empty?
    puts "  ⚠️  No links found in this post"
    puts "  Post data type: #{post.post.dig('record', '$type')}"
    puts "  Post text: #{post.post.dig('record', 'text')&.truncate(100)}"
    puts "  Has embed: #{!post.post.dig('record', 'embed').nil?}"
    if post.post.dig("record", "embed")
      puts "  Embed type: #{post.post.dig('record', 'embed', '$type')}"
      if post.post.dig("record", "embed", "$type") == "app.bsky.embed.external"
        puts "  External URI: #{post.post.dig('record', 'embed', 'external', 'uri')}"
      end
    end
    puts "  Has facets: #{!post.post.dig('record', 'facets').nil?}"
    if post.post.dig("record", "facets")
      puts "  Facets count: #{post.post.dig('record', 'facets').length}"
    end
  else
    puts "  🔗 Found #{links.count} link(s):"
    links.each do |link|
      puts "    - #{link}"
      
      # Check if an article was created for this link
      article = Article.find_by(url: link)
      if article
        puts "      ✅ Article captured!"
        puts "        Title: #{article.title}"
        puts "        Created: #{article.created_at}"
        puts "        ID: #{article.id}"
        
        # Check if ArticlePost exists
        article_post = ArticlePost.find_by(post: post, article: article)
        if article_post
          puts "        ✅ Linked to this post (ArticlePost ID: #{article_post.id})"
        else
          puts "        ⚠️  Article exists but not linked to this post"
        end
      else
        puts "      ❌ No article found for this link"
      end
    end
  end
  puts
end

puts "=" * 80
puts "Summary:"
puts "  Source: #{source.atproto_did}"
puts "  Posts: #{posts.count}"
puts "  Total links found: #{posts.sum { |p| LinkDetectionService.call(p).count }}"
puts "  Articles created: #{posts.joins(:articles).distinct.count('articles.id')}"

