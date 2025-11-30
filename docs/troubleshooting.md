# Troubleshooting Guide

## Common Issues and Solutions

### Worker Service Not Running

**Symptoms:**
- Posts are being created but articles are not
- Jobs are enqueued but not processed
- Health check shows `workers_size: 0`

**Cause:**
The `feedbrainer_worker` service uses Sidekiq to process background jobs. If it's not running, jobs will queue up but never execute.

**Solution:**
```bash
# Check if worker is running
docker-compose ps feedbrainer_worker

# Start the worker service
docker-compose up -d feedbrainer_worker

# Verify it's processing jobs
docker-compose logs feedbrainer_worker --tail=20
```

**Prevention:**
The worker service is now configured to start automatically with `docker-compose up`. It uses the same build configuration as other services, so it will be built and started automatically.

### Posts Created But No Articles

**Symptoms:**
- Posts appear in database
- No articles are created
- Health check shows posts but no articles

**Possible Causes:**

1. **Worker not running** (most common)
   - See "Worker Service Not Running" above

2. **No links in posts**
   - Check if posts have links: `GET /health/test_did?did=<DID>`
   - Links must be in post facets or text

3. **Links not detected as news articles**
   - The system only creates articles for URLs with JSON-LD NewsArticle schema
   - Check worker logs for processing details

4. **Link detection failing**
   - Check `LinkDetectionService` logs
   - Verify post structure has facets or text with URLs

**Debugging:**
```bash
# Check if worker is processing jobs
docker-compose exec feedbrainer bin/rails runner "require 'sidekiq/api'; puts Sidekiq::Stats.new.enqueued"

# Check recent posts and their links
docker-compose exec feedbrainer bin/rails runner "Post.where('created_at > ?', 1.hour.ago).each { |p| links = LinkDetectionService.call(p); puts \"Post #{p.id}: #{links.length} links\" }"

# Check worker logs for errors
docker-compose logs feedbrainer_worker --tail=50 | grep -E "(Error|Failed|Exception)"
```

### Health Check Shows Degraded Status

**Check individual components:**
```bash
# Detailed health check
curl http://localhost:3001/health/detailed | jq .

# Pipeline-specific check
curl http://localhost:3001/health/pipeline | jq .
```

**Common issues:**
- **Skybeam cache empty**: Check if sources are in database, Skybeam may need to refresh cache
- **Redis connection failed**: Verify Redis is running and accessible
- **No recent posts**: Check if firehose is receiving events
- **Consumer not active**: Check if `feedbrainer_consumer` service is running

### Services Not Starting Automatically

**All services should start with:**
```bash
docker-compose up -d
```

**If a service doesn't start:**
1. Check service status: `docker-compose ps`
2. Check logs: `docker-compose logs <service_name>`
3. Verify dependencies: Services with `depends_on` wait for dependencies to be healthy
4. Rebuild if needed: `docker-compose up -d --build <service_name>`

### Database Connection Issues

**Symptoms:**
- `ActiveRecord::DatabaseConnectionError`
- Health check shows database as unhealthy

**Solution:**
```bash
# Check postgres is running and healthy
docker-compose ps postgres

# Check connection from feedbrainer
docker-compose exec feedbrainer bin/rails runner "ActiveRecord::Base.connection.execute('SELECT 1')"
```

### Redis Connection Issues

**Symptoms:**
- Jobs not processing
- Queue length growing
- Health check shows Redis as unhealthy

**Solution:**
```bash
# Check Redis is running
docker-compose ps redis

# Check queue length
docker-compose exec redis redis-cli LLEN bluesky:firehose

# Test connection
docker-compose exec feedbrainer bin/rails runner "Redis.new(url: ENV['REDIS_URL']).ping"
```

## Service Dependencies

The services have the following dependencies:

- `feedbrainer` → `postgres` (healthy), `redis` (started)
- `feedbrainer_consumer` → `postgres` (healthy), `redis` (started)
- `feedbrainer_worker` → `postgres` (healthy), `redis` (started)
- `skybeam` → `postgres` (healthy)
- `skytorch` → `redis` (started)

Services with `depends_on` will wait for dependencies to be ready before starting.

## Health Check Endpoints

Use these endpoints to diagnose issues:

- `GET /health` - Basic health check
- `GET /health/detailed` - Full system health
- `GET /health/pipeline` - Pipeline-specific health
- `GET /health/test_did?did=<DID>` - Test specific DID

See `docs/health_checks.md` for detailed documentation.

