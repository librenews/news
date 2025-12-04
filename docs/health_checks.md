# Health Check Endpoints

Feedbrainer now includes comprehensive health check endpoints to monitor the end-to-end pipeline.

## Endpoints

### Basic Health Check
```
GET /health
```
Returns a simple status indicating if the service is running.

### Detailed Health Check
```
GET /health/detailed
```
Returns comprehensive health status for all components:
- Database connectivity and latency
- Redis connectivity and latency
- Skybeam service status
- Skytorch service status
- Sidekiq consumer status
- Pipeline activity (recent posts)
- Source count

### Pipeline Health Check
```
GET /health/pipeline
```
Returns detailed pipeline health:
- **skybeam_cache**: Verifies Skybeam has DIDs cached and shows count
- **redis_queue**: Shows queue length and status
- **recent_posts**: Lists recent posts (last 10 minutes) with age
- **consumer_active**: Shows Sidekiq worker status

### Test Specific DID
```
GET /health/test_did?did=<DID>
```
Tests if a specific DID's posts are being captured:
- Checks if DID is in database
- Checks if DID is in Skybeam cache
- Shows recent posts (last hour) for that DID
- Useful for debugging why a specific source isn't being captured

## Usage Examples

### Check overall system health
```bash
curl http://localhost:3001/health/detailed | jq .
```

### Check pipeline status
```bash
curl http://localhost:3001/health/pipeline | jq .
```

### Test if your DID is being captured
```bash
curl "http://localhost:3001/health/test_did?did=did:plc:iq44hcebgqaom6jvtcd3ln73" | jq .
```

## Response Status Codes

- **200**: All checks passed (healthy)
- **503**: One or more checks failed (degraded/unhealthy)
- **400**: Bad request (missing parameters)
- **404**: Resource not found (e.g., DID not in database)

## Interpreting Results

### Healthy Status
All components are working correctly:
- Database is accessible
- Redis is accessible
- Skybeam is running and has DIDs cached
- Recent posts are being processed
- Consumer is active

### Degraded Status
Some components may have issues:
- Check individual component status in the response
- Look for error messages in failed checks
- Common issues:
  - Skybeam cache empty (no DIDs cached)
  - No recent posts (pipeline may be stalled)
  - Consumer not active (jobs not processing)

### Testing a Specific DID

If a DID's posts aren't being captured:

1. **Check if source exists in database:**
   ```bash
   curl "http://localhost:3001/health/test_did?did=<YOUR_DID>" | jq .
   ```

2. **If source not found:**
   - Verify the source is in the `sources` table
   - Check if the DID format is correct

3. **If source exists but not in Skybeam cache:**
   - Skybeam may need to refresh its cache
   - Check Skybeam logs: `docker-compose logs skybeam | grep cache`

4. **If in cache but no recent posts:**
   - Check if posts are actually being posted from that DID
   - Check Skybeam logs for "Relevant post" messages
   - Check consumer logs: `docker-compose logs feedbrainer_consumer --tail=50`

## Monitoring

You can set up monitoring to periodically check these endpoints:

```bash
# Check every 5 minutes
watch -n 300 'curl -s http://localhost:3001/health/pipeline | jq .status'
```

Or use a monitoring service like UptimeRobot, Pingdom, etc. to monitor `/health` endpoint.

