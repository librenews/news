#!/usr/bin/env ruby
# script/firehose_consumer.rb
# Blocking Redis queue consumer for real-time Bluesky post processing

require_relative '../config/environment'

# Define helper method before using it
def process_message(json)
  begin
    data = JSON.parse(json)
    
    # 1. Detect Links immediately
    links = LinkDetectionService.call(data)
    
    if links.any?
      # 2. Enqueue Ingestion Job
      # We pass the raw data and the extracted links to the job
      IngestPostJob.perform_later(data, links)
      puts "Enqueued IngestPostJob for #{links.count} links"
    else
      # Drop it
      # puts "Dropped post (no links)"
    end

  rescue JSON::ParserError => e
    puts "Failed to parse JSON: #{e.message}"
    Rails.logger.error("Failed to parse firehose message: #{e.message}")
  rescue => e
    puts "Error processing message: #{e.message}"
    Rails.logger.error("Unexpected error processing message: #{e.class} - #{e.message}")
    puts e.backtrace.join("\n")
  end
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
