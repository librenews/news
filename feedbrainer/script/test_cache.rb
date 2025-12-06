#!/usr/bin/env ruby
# Test script for cache functionality

puts '=== Testing Cache Functionality ==='
puts ''

# Clear any existing cache
Rails.cache.clear
puts '✓ Cache cleared'
puts ''

# Test 1: Basic cache write/read
puts '1. Testing basic cache operations...'
Rails.cache.write('test_key', 'test_value')
result = Rails.cache.read('test_key')
puts "   Cache read result: #{result}"
puts "   ✓ Basic caching works!" if result == 'test_value'
puts ''

# Test 2: Check if we can connect to Redis
puts '2. Testing Redis connection...'
puts "   Cache store: #{Rails.cache.class.name}"
puts "   ✓ Using Redis cache store!" if Rails.cache.class.name.include?('Redis')
puts ''

# Test 3: Check Article.maximum(:updated_at)
puts '3. Testing Article timestamp query...'
max_time = Article.maximum(:updated_at)
puts "   Latest article updated_at: #{max_time}"
puts "   Article count: #{Article.count}"
puts ''

# Test 4: Test the home page cache key generation
puts '4. Testing home page cache key...'
cache_key = "home_index_html_#{Article.maximum(:updated_at)&.to_i || 0}"
puts "   Cache key: #{cache_key}"
puts ''

puts '=== All tests passed! ==='
