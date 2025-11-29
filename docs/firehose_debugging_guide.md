# Bluesky Firehose End-to-End Debugging Guide

## 🚀 GETTING IT WORKING - Quick Start

If nothing is working, follow these steps in order:

### Step 1: Run the End-to-End Test
```bash
docker-compose exec feedbrainer bin/rails runner script/test_end_to_end.rb
```

This will tell you exactly what's broken.

### Step 2: Fix Common Issues

**If Source is missing:**
```bash
docker-compose exec feedbrainer bin/rails runner "Source.create!(atproto_did: 'did:plc:iq44hcebgqaom6jvtcd3ln73')"
```

**If Redis is hung/unresponsive:**
```bash
docker-compose restart redis
# Wait 10 seconds, then:
docker-compose exec feedbrainer bin/rails runner script/quick_check_queue.rb
```

**If queue is backed up (>1000 messages):**
```bash
# Option 1: Clear it (lose messages)
docker-compose exec redis redis-cli DEL bluesky:firehose

# Option 2: Let it process (may take time)
# Just restart consumer and wait
docker-compose restart feedbrainer_consumer
```

**If Skybeam cache is stale:**
```bash
# Refresh the cache
curl -X POST http://localhost:4101/debug/cache/refresh
```

**If consumer isn't running:**
```bash
docker-compose up -d feedbrainer_consumer
docker-compose logs -f feedbrainer_consumer
```

### Step 3: Restart Everything (Nuclear Option)
```bash
# Stop everything
docker-compose down

# Start in order
docker-compose up -d postgres redis
sleep 5
docker-compose up -d feedbrainer skybeam
sleep 5
docker-compose up -d feedbrainer_consumer

# Wait 30 seconds for Skybeam to refresh cache
sleep 30

# Test again
docker-compose exec feedbrainer bin/rails runner script/test_end_to_end.rb
```

### Step 4: Verify It's Working
```bash
# Watch for new posts in real-time
docker-compose exec feedbrainer bin/rails runner "
  loop do
    count = Post.where('created_at > ?', 1.minute.ago).count
    puts \"[#{Time.now.strftime('%H:%M:%S')}] Posts in last minute: #{count}\"
    sleep 10
  end
"
```

## Architecture Overview

```
Bluesky → Jetstream Client → SourceCache Filter → Producer → Redis Queue → Rails Consumer → Post Model
   (1)          (2)                 (3)              (4)         (5)            (6)            (7)
```

## Debugging Each Stage

### Stage 1: Is Bluesky Sending Posts?

**Check Jetstream is receiving data:**
```bash
# Watch raw Jetstream connection
docker compose logs skybeam | grep "Connected to Jetstream"

# Count messages received per minute
docker compose logs skybeam --since 1m | grep -c "handle_frame"
```

**Manual test - connect directly to Jetstream:**
```bash
# Install websocat: brew install websocat
websocat "wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post" | jq '.did'
```

### Stage 2: Is Jetstream Client Working?

**Check for connection issues:**
```bash
docker compose logs skybeam | grep -E "Connecting|Connected|Disconnected"
```

**Expected output:**
```
[info] Connecting to Jetstream at wss://...
[info] Connected to Jetstream
```

### Stage 3: Is SourceCache Filtering Correctly?

**Check if your DID is in the cache:**
```bash
# Get DIDs from feedbrainer API
curl http://localhost:3001/api/sources | jq

# Check SourceCache refresh logs
docker compose logs skybeam | grep "Refreshed source DIDs"
```

**Test if a specific DID is cached:**
```elixir
# In Elixir console
docker compose exec skybeam iex -S mix

# Check if DID exists
Skybeam.SourceCache.exists?("did:plc:YOUR_DID_HERE")
```

### Stage 4: Is Producer Pushing to Redis?

**Check Producer logs:**
```bash
docker compose logs skybeam | grep -E "Pushed.*messages to Redis"
```

**Monitor Redis queue in real-time:**
```bash
# Watch queue length
watch -n 1 'docker compose exec redis redis-cli LLEN bluesky:firehose'

# See what's in the queue
docker compose exec redis redis-cli LRANGE bluesky:firehose 0 5 | jq
```

### Stage 5: Is Redis Queue Receiving Messages?

**Check queue stats:**
```bash
# Current queue depth
docker compose exec redis redis-cli LLEN bluesky:firehose

# Monitor queue activity
docker compose exec redis redis-cli MONITOR | grep bluesky:firehose
```

### Stage 6: Is Rails Consumer Running?

**Check consumer is alive:**
```bash
docker compose ps feedbrainer_consumer

# Should show: Up X minutes
```

**Check consumer logs:**
```bash
# See if consumer started
docker compose logs feedbrainer_consumer | grep "Starting firehose consumer"

# Watch for processing activity
docker compose logs -f feedbrainer_consumer
```

### Stage 7: Are Posts Being Created?

**Check Rails database:**
```bash
docker compose exec feedbrainer rails console

# In Rails console:
Post.count
Post.last
Post.where("created_at > ?", 5.minutes.ago).count
```

## Enhanced Logging

### Add Debug Logging to Each Stage

**1. Skybeam - Log every DID checked:**
```elixir
# In lib/skybeam/firehose/pipeline.ex, handle_message
Logger.info("Checking DID: #{did} - Exists: #{SourceCache.exists?(did)}")
```

**2. Skybeam - Log every message pushed:**
```elixir
# In lib/skybeam/firehose/pipeline.ex, handle_batch
Logger.info("Pushing #{length(messages)} messages to Redis for DIDs: #{Enum.map(messages, & &1.data["did"]) |> Enum.join(", ")}")
```

**3. Rails Consumer - Log every message received:**
```ruby
# In script/firehose_consumer.rb, process_message
Rails.logger.info("Processing message for DID: #{did}")
```

## End-to-End Test Script

Create `script/test_firehose.rb`:
```ruby
#!/usr/bin/env ruby
require_relative '../config/environment'

puts "=== Firehose End-to-End Test ==="
puts

# 1. Check Sources
puts "1. Sources in database:"
sources = Source.where.not(atproto_did: nil)
if sources.empty?
  puts "   ❌ No sources with atproto_did found!"
  exit 1
else
  sources.each do |s|
    puts "   ✓ #{s.name}: #{s.atproto_did}"
  end
end
puts

# 2. Check Feedbrainer API
puts "2. Feedbrainer API (/api/sources):"
require 'net/http'
response = Net::HTTP.get(URI('http://localhost:3001/api/sources'))
dids = JSON.parse(response)
puts "   ✓ Returns #{dids.length} DIDs"
dids.each { |did| puts "     - #{did}" }
puts

# 3. Check Redis queue
puts "3. Redis queue depth:"
redis = Redis.new(url: ENV['REDIS_URL'])
queue_length = redis.llen('bluesky:firehose')
puts "   Queue length: #{queue_length}"
if queue_length > 0
  puts "   Sample message:"
  sample = redis.lindex('bluesky:firehose', 0)
  puts "   #{JSON.pretty_generate(JSON.parse(sample))}"
end
puts

# 4. Check recent Posts
puts "4. Recent Posts (last 5 minutes):"
recent_posts = Post.where("created_at > ?", 5.minutes.ago)
puts "   Count: #{recent_posts.count}"
recent_posts.limit(5).each do |post|
  puts "   - Source: #{post.source.name}, DID: #{post.post['did']}"
end
puts

# 5. Consumer status
puts "5. Consumer process:"
system("docker compose ps feedbrainer_consumer")
puts

puts "=== Test Complete ==="
```

Run it:
```bash
docker compose exec feedbrainer ruby script/test_firehose.rb
```

## Real-Time Monitoring Dashboard

Create `script/monitor_firehose.rb`:
```ruby
#!/usr/bin/env ruby
require_relative '../config/environment'
require 'io/console'

def clear_screen
  print "\e[2J\e[H"
end

redis = Redis.new(url: ENV['REDIS_URL'])

loop do
  clear_screen
  puts "=== Firehose Monitor (#{Time.now.strftime('%H:%M:%S')}) ==="
  puts
  
  # Queue stats
  queue_length = redis.llen('bluesky:firehose')
  puts "Redis Queue: #{queue_length} messages"
  puts
  
  # Recent posts
  recent = Post.where("created_at > ?", 1.minute.ago).count
  puts "Posts (last 1 min): #{recent}"
  puts "Posts (last 5 min): #{Post.where("created_at > ?", 5.minutes.ago).count}"
  puts "Posts (last 1 hour): #{Post.where("created_at > ?", 1.hour.ago).count}"
  puts
  
  # Per-source breakdown
  puts "Posts by Source (last hour):"
  Post.where("created_at > ?", 1.hour.ago)
      .joins(:source)
      .group("sources.name")
      .count
      .each { |name, count| puts "  #{name}: #{count}" }
  
  puts
  puts "Press Ctrl+C to exit"
  
  sleep 2
end
```

Run it:
```bash
docker compose exec feedbrainer ruby script/monitor_firehose.rb
```

## Common Issues & Solutions

### Issue: No messages in Redis queue

**Diagnosis:**
```bash
# Check if Skybeam is connected
docker compose logs skybeam | grep "Connected to Jetstream"

# Check if DIDs are cached
docker compose logs skybeam | grep "Refreshed source DIDs. Count:"
```

**Solutions:**
- If count is 0: Add Sources with `atproto_did`
- If not connected: Check network/Jetstream status
- If connected but no messages: Your sources may not be posting

### Issue: Messages in queue but not processed

**Diagnosis:**
```bash
# Check consumer is running
docker compose ps feedbrainer_consumer

# Check for errors
docker compose logs feedbrainer_consumer | grep -i error
```

**Solutions:**
- If not running: `docker compose up -d feedbrainer_consumer`
- If errors: Check database connection, Redis connection

### Issue: Posts processed but not in database

**Diagnosis:**
```bash
# Check for validation errors
docker compose logs feedbrainer_consumer | grep "RecordInvalid"

# Check for missing sources
docker compose logs feedbrainer_consumer | grep "unknown DID"
```

**Solutions:**
- Add missing Source records
- Fix validation issues in Post model

## Quick Health Check

One-liner to check entire pipeline:
```bash
echo "Jetstream: $(docker compose logs skybeam --tail 100 | grep -c 'Connected to Jetstream')" && \
echo "Cache DIDs: $(docker compose logs skybeam --tail 100 | grep 'Refreshed source DIDs' | tail -1)" && \
echo "Queue depth: $(docker compose exec redis redis-cli LLEN bluesky:firehose)" && \
echo "Consumer: $(docker compose ps feedbrainer_consumer | grep Up)" && \
echo "Posts (5min): $(docker compose exec feedbrainer rails runner 'puts Post.where("created_at > ?", 5.minutes.ago).count')"
```
