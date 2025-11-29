#!/usr/bin/env ruby
# script/firehose_consumer.rb
# Blocking Redis queue consumer for real-time Bluesky post processing

require_relative '../config/environment'

# Define helper method before using it
def process_message(json)
  event = JSON.parse(json)
  did = event['did']
  
  # Find source by DID
  source = Source.find_by(atproto_did: did)
  
  if source.nil?
    puts "Firehose message for unknown DID: #{did}"
    Rails.logger.warn("Firehose message for unknown DID: #{did}")
    return
  end
  
  # Create post through Rails model (validations, callbacks, etc.)
  source.posts.create!(post: event)
  
  puts "Created post for source #{source.id} (#{did})"
  Rails.logger.debug("Created post for source #{source.id} (#{did})")
  
rescue JSON::ParserError => e
  puts "Failed to parse firehose message: #{e.message}"
  Rails.logger.error("Failed to parse firehose message: #{e.message}")
rescue ActiveRecord::RecordInvalid => e
  puts "Failed to create post: #{e.message}"
  Rails.logger.error("Failed to create post: #{e.message}")
rescue => e
  puts "Unexpected error processing message: #{e.class} - #{e.message}"
  Rails.logger.error("Unexpected error processing message: #{e.class} - #{e.message}")
end

# Use default ruby driver
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
STDOUT.sync = true
puts "Connecting to Redis at #{redis_url}..."
redis = Redis.new(url: redis_url)

consumer_name = "consumer-#{Socket.gethostname}-#{Process.pid}"
puts "Starting firehose consumer: #{consumer_name}"
Rails.logger.info("Starting firehose consumer: #{consumer_name}")

loop do
  begin
    # BRPOP blocks until a message arrives (timeout: 0 = wait forever)
    # Returns: ["queue_name", "message"]
    queue, json = redis.brpop('bluesky:firehose', timeout: 0)
    
    puts "Received message from #{queue}"
    process_message(json)
    
  rescue => e
    puts "Firehose consumer error: #{e.class} - #{e.message}"
    Rails.logger.error("Firehose consumer error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    sleep 1  # Brief pause before retry
  end
end
