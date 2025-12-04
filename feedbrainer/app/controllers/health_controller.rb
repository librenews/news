require "net/http"
require "json"

class HealthController < ApplicationController
  # Skip CSRF protection for health checks
  skip_before_action :verify_authenticity_token

  def show
    # Basic health check - just verify the app is running
    render json: { status: "ok", service: "feedbrainer" }
  end

  def detailed
    checks = {
      database: check_database,
      redis: check_redis,
      skybeam: check_skybeam,
      skytorch: check_skytorch,
      consumer: check_consumer,
      pipeline: check_pipeline,
      sources: check_sources
    }

    all_healthy = checks.values.all? { |check| check[:status] == "healthy" }
    status_code = all_healthy ? 200 : 503

    render json: {
      status: all_healthy ? "healthy" : "degraded",
      service: "feedbrainer",
      checks: checks,
      timestamp: Time.current.iso8601
    }, status: status_code
  end

  def pipeline
    # End-to-end pipeline health check
    pipeline_checks = {
      skybeam_cache: check_skybeam_cache,
      redis_queue: check_redis_queue,
      recent_posts: check_recent_posts,
      consumer_active: check_consumer_active
    }

    all_healthy = pipeline_checks.values.all? { |check| check[:status] == "healthy" }
    status_code = all_healthy ? 200 : 503

    render json: {
      status: all_healthy ? "healthy" : "degraded",
      service: "feedbrainer",
      pipeline: pipeline_checks,
      timestamp: Time.current.iso8601
    }, status: status_code
  end

  def test_did
    # Test if a specific DID's posts are being captured
    did = params[:did] || params[:did]
    
    if did.blank?
      render json: {
        status: "error",
        message: "Missing 'did' parameter"
      }, status: 400
      return
    end

    source = Source.find_by(atproto_did: did)
    
    if source.nil?
      render json: {
        status: "not_found",
        did: did,
        message: "Source not found in database",
        suggestion: "Check if this DID is in the sources table and if Skybeam has it cached"
      }, status: 404
      return
    end

    # Check if DID is in Skybeam cache
    skybeam_cache_status = check_did_in_skybeam_cache(did)
    
    # Get recent posts
    recent_posts = source.posts.where("created_at > ?", 1.hour.ago)
                          .order(created_at: :desc)
                          .limit(10)
    
    posts_data = recent_posts.map do |post|
      {
        id: post.id,
        created_at: post.created_at.iso8601,
        age_minutes: ((Time.current - post.created_at) / 60).round(1),
        has_link: post.post&.dig("record", "text")&.match?(%r{https?://})
      }
    end

    render json: {
      status: "ok",
      did: did,
      source_id: source.id,
      skybeam_cache: skybeam_cache_status,
      recent_posts_1h: posts_data.length,
      posts: posts_data,
      latest_post_age_minutes: posts_data.first ? posts_data.first[:age_minutes] : nil,
      message: posts_data.length > 0 ? 
        "Source is active with #{posts_data.length} posts in last hour" : 
        "No posts in last hour for this source"
    }
  end

  private

  def check_did_in_skybeam_cache(did)
    skybeam_url = ENV.fetch("SKYBEAM_URL", "http://skybeam:4000")
    uri = URI.parse("#{skybeam_url}/debug/cache/check")
    uri.query = URI.encode_www_form({ did: did })
    
    response = Net::HTTP.get_response(uri)
    
    if response.code.to_i == 200
      data = JSON.parse(response.body)
      {
        in_cache: data["in_cache"] || false,
        total_cached: data["total_cached"] || 0
      }
    else
      {
        in_cache: false,
        error: "HTTP #{response.code}"
      }
    end
  rescue => e
    {
      in_cache: false,
      error: e.message
    }
  end

  private

  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute("SELECT 1")
    duration = ((Time.current - start_time) * 1000).round(2)

    {
      status: "healthy",
      latency_ms: duration
    }
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_redis
    redis_url = ENV.fetch("REDIS_URL", "redis://redis:6379/0")
    redis = Redis.new(url: redis_url)
    
    start_time = Time.current
    redis.ping
    duration = ((Time.current - start_time) * 1000).round(2)

    {
      status: "healthy",
      latency_ms: duration
    }
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_skybeam
    skybeam_url = ENV.fetch("SKYBEAM_URL", "http://skybeam:4000")
    uri = URI.parse("#{skybeam_url}/health")
    
    start_time = Time.current
    response = Net::HTTP.get_response(uri)
    duration = ((Time.current - start_time) * 1000).round(2)

    if response.code.to_i == 200
      {
        status: "healthy",
        latency_ms: duration
      }
    else
      {
        status: "unhealthy",
        error: "HTTP #{response.code}"
      }
    end
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_skytorch
    skytorch_url = ENV.fetch("SKYTORCH_URL", "http://skytorch:5000")
    uri = URI.parse("#{skytorch_url}/health")
    
    start_time = Time.current
    response = Net::HTTP.get_response(uri)
    duration = ((Time.current - start_time) * 1000).round(2)

    if response.code.to_i == 200
      {
        status: "healthy",
        latency_ms: duration
      }
    else
      {
        status: "unhealthy",
        error: "HTTP #{response.code}"
      }
    end
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_consumer
    # Check if Sidekiq is processing jobs
    begin
      require "sidekiq/api"
      stats = Sidekiq::Stats.new
      {
        status: "healthy",
        processed: stats.processed,
        failed: stats.failed,
        enqueued: stats.enqueued,
        workers_size: stats.workers_size
      }
    rescue => e
      {
        status: "unhealthy",
        error: e.message
      }
    end
  end

  def check_pipeline
    # Check if we have recent posts (within last 10 minutes)
    recent_posts = Post.where("created_at > ?", 10.minutes.ago).count
    
    {
      status: recent_posts > 0 ? "healthy" : "warning",
      recent_posts_10min: recent_posts,
      message: recent_posts > 0 ? "Pipeline is active" : "No recent posts in last 10 minutes"
    }
  end

  def check_sources
    source_count = Source.count
    {
      status: source_count > 0 ? "healthy" : "warning",
      count: source_count,
      message: source_count > 0 ? "#{source_count} sources configured" : "No sources configured"
    }
  end

  def check_skybeam_cache
    skybeam_url = ENV.fetch("SKYBEAM_URL", "http://skybeam:4000")
    # Check cache with a test DID - we'll get all cached DIDs in response
    test_did = Source.first&.atproto_did || "did:plc:test"
    uri = URI.parse("#{skybeam_url}/debug/cache/check")
    uri.query = URI.encode_www_form({ did: test_did })
    
    response = Net::HTTP.get_response(uri)
    
    if response.code.to_i == 200
      data = JSON.parse(response.body)
      cached_dids = data["all_dids"] || []
      source_count = Source.count
      
      {
        status: cached_dids.length > 0 ? "healthy" : "warning",
        cached_did_count: cached_dids.length,
        source_count: source_count,
        cached_dids: cached_dids.first(5), # Show first 5
        message: cached_dids.length > 0 ? "#{cached_dids.length} DIDs cached" : "No DIDs in cache"
      }
    else
      {
        status: "unhealthy",
        error: "HTTP #{response.code}: #{response.body}"
      }
    end
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_redis_queue
    redis_url = ENV.fetch("REDIS_URL", "redis://redis:6379/0")
    redis = Redis.new(url: redis_url)
    queue_length = redis.llen("bluesky:firehose")
    
    {
      status: "healthy",
      queue_length: queue_length,
      message: queue_length > 0 ? "#{queue_length} messages in queue" : "Queue is empty"
    }
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_recent_posts
    recent_posts = Post.where("created_at > ?", 10.minutes.ago)
                       .order(created_at: :desc)
                       .limit(5)
    
    posts_data = recent_posts.map do |post|
      links = LinkDetectionService.call(post)
      {
        id: post.id,
        created_at: post.created_at.iso8601,
        age_minutes: ((Time.current - post.created_at) / 60).round(1),
        source_did: post.source&.atproto_did,
        links_found: links.length
      }
    end
    
    recent_articles = Article.where("created_at > ?", 10.minutes.ago).count
    
    {
      status: posts_data.length > 0 ? "healthy" : "warning",
      count: posts_data.length,
      posts: posts_data,
      articles_created_10min: recent_articles,
      message: posts_data.length > 0 ? "#{posts_data.length} posts in last 10 minutes, #{recent_articles} articles created" : "No posts in last 10 minutes"
    }
  end

  def check_consumer_active
    # Check if consumer process is running by checking for recent Sidekiq activity
    # or by checking if jobs are being processed
    begin
      require "sidekiq/api"
      stats = Sidekiq::Stats.new
      workers_active = stats.workers_size > 0
      
      # Also check if we have a feedbrainer_consumer process
      # This is a simple heuristic - if Sidekiq has workers, consumer might be active
      {
        status: workers_active ? "healthy" : "warning",
        workers_size: stats.workers_size,
        processed: stats.processed,
        message: workers_active ? "Workers active" : "No active workers"
      }
    rescue => e
      {
        status: "unhealthy",
        error: e.message
      }
    end
  end
end

