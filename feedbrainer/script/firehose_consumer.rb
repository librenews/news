#!/usr/bin/env ruby
# script/firehose_consumer.rb
# Blocking Redis queue consumer for real-time Bluesky post processing

require_relative '../config/environment'

# Use hiredis for better performance
redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'), driver: :hiredis)

consumer_name = "consumer-#{Socket.gethostname}-#{Process.pid}"
Rails.logger.info("Starting firehose consumer: #{consumer_name}")

loop do
  begin
    # BRPOP blocks until a message arrives (timeout: 0 = wait forever)
    # Returns: ["queue_name", "message"]
    _, json = redis.brpop('bluesky:firehose', timeout: 0)
    
    process_message(json)
    
  rescue => e
    Rails.logger.error("Firehose consumer error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    sleep 1  # Brief pause before retry
  end
end

def process_message(json)
  event = JSON.parse(json)
  did = event['did']
  
  # Find source by DID
  source = Source.find_by(atproto_did: did)
  
  if source.nil?
    Rails.logger.warn("Firehose message for unknown DID: #{did}")
    return
  end
  
  # Create post through Rails model (validations, callbacks, etc.)
  source.posts.create!(post: event)
  
  Rails.logger.debug("Created post for source #{source.id} (#{did})")
  
rescue JSON::ParserError => e
  Rails.logger.error("Failed to parse firehose message: #{e.message}")
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.error("Failed to create post: #{e.message}")
rescue => e
  Rails.logger.error("Unexpected error processing message: #{e.class} - #{e.message}")
end
