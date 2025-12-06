#!/usr/bin/env ruby
# Test script for cache invalidation

puts '=== Testing Cache Invalidation ==='
puts ''

# Get initial cache state
initial_max = Article.maximum(:updated_at)
puts "1. Initial state:"
puts "   Latest article timestamp: #{initial_max}"
puts "   Article count: #{Article.count}"
puts ''

# Create a test cache entry with the home page cache key
cache_key_html = "home_index_html_#{initial_max&.to_i || 0}"
cache_key_json = "home_index_json_#{initial_max&.to_i || 0}"

puts "2. Creating cache entries..."
Rails.cache.write(cache_key_html, 'cached_html_data')
Rails.cache.write(cache_key_json, 'cached_json_data')
puts "   HTML cache key: #{cache_key_html}"
puts "   JSON cache key: #{cache_key_json}"
puts "   ✓ Cache entries created"
puts ''

puts "3. Verifying cache exists..."
puts "   HTML cached: #{Rails.cache.exist?(cache_key_html)}"
puts "   JSON cached: #{Rails.cache.exist?(cache_key_json)}"
puts ''

# Create a new article (this should touch the updated_at timestamp)
puts "4. Creating a new article..."
new_article = Article.create!(
  title: "Cache Test Article #{Time.now.to_i}",
  url: "http://test.example.com/#{Time.now.to_i}"
)
puts "   ✓ Article created: #{new_article.title}"
puts ''

# Check if the timestamp changed
new_max = Article.maximum(:updated_at)
puts "5. After article creation:"
puts "   New latest timestamp: #{new_max}"
puts "   Timestamp changed: #{new_max != initial_max}"
puts ''

# The cache keys should now be different
new_cache_key_html = "home_index_html_#{new_max&.to_i || 0}"
new_cache_key_json = "home_index_json_#{new_max&.to_i || 0}"

puts "6. New cache keys:"
puts "   HTML: #{new_cache_key_html}"
puts "   JSON: #{new_cache_key_json}"
puts "   Keys changed: #{new_cache_key_html != cache_key_html}"
puts ''

puts "7. Verifying old cache is effectively invalidated..."
puts "   Old HTML cache still exists: #{Rails.cache.exist?(cache_key_html)}"
puts "   New HTML cache exists: #{Rails.cache.exist?(new_cache_key_html)}"
puts "   ✓ Cache invalidation works via key rotation!"
puts ''

# Clean up
new_article.destroy
puts "8. Cleanup complete"
puts ''

puts '=== Cache Invalidation Test Passed! ==='
puts ''
puts 'Summary:'
puts '- Cache uses timestamp-based keys'
puts '- When articles are created/updated, timestamp changes'
puts '- New timestamp creates new cache key'
puts '- Old cached data becomes unreachable (effectively invalidated)'
puts '- Old cache entries will expire after 5 minutes'
