# Kamal Deployment Guide

This guide covers deploying the multi-container application to production using Kamal.

## Prerequisites

1. **Server Setup**
   - Server IP: `164.90.132.64`
   - SSH access configured for user `deploy`
   - Docker installed on the server
   - Domain `open.news` pointing to the server IP

2. **Local Setup**
   - Kamal installed: `gem install kamal`
   - Docker Hub credentials configured
   - SSH access to the server

3. **Secrets Configuration**
   - Copy `.kamal/secrets.example` to `.kamal/secrets`
   - Fill in all required secrets (see below)

## Configuration Files

### `.kamal/secrets`

This file contains production secrets and should **NEVER** be committed to version control.

Required secrets:
- `KAMAL_REGISTRY_PASSWORD`: Docker Hub access token
- `RAILS_MASTER_KEY`: From `feedbrainer/config/master.key`
- `POSTGRES_PASSWORD`: Database password
- `ATPROTO_HANDLE`: AT Protocol handle (e.g., `open.news`)
- `ATPROTO_PASSWORD`: AT Protocol app password

### `config/deploy/kamal.yml`

Main deployment configuration file. Key settings:
- **Service name**: `news`
- **Registry**: Docker Hub (`lbrenews`)
- **Server**: `164.90.132.64`
- **Domain**: `open.news` (with SSL)
- **Network**: `news-app` (shared Docker network)

## Services

The deployment includes:

1. **feedbrainer** (Rails app) - Main application
2. **db** (PostgreSQL with pgvector) - Database
3. **redis** - Cache and job queue
4. **skybeam** (Elixir/Phoenix) - Accessory service
5. **skytorch** (Python FastAPI) - Accessory service
6. **skywire** (Node.js) - Accessory service

## Deployment Steps

### 1. Build and Push Custom Images

Before deploying, you need to build and push the custom service images (skybeam, skytorch, skywire) to Docker Hub:

```bash
# Option 1: Use the helper script
export REGISTRY_PASSWORD=$(grep KAMAL_REGISTRY_PASSWORD .kamal/secrets | cut -d'=' -f2)
./scripts/build-and-push-images.sh

# Option 2: Build and push manually
docker login -u lbrenews
docker build -f docker/skybeam/Dockerfile --target production -t lbrenews/skybeam:latest .
docker push lbrenews/skybeam:latest

docker build -f docker/skytorch/Dockerfile --target production -t lbrenews/skytorch:latest .
docker push lbrenews/skytorch:latest

docker build -f docker/skywire/Dockerfile --target production -t lbrenews/skywire:latest .
docker push lbrenews/skywire:latest
```

### 2. Initial Setup

```bash
# Verify Kamal can connect to the server
kamal app details -c config/deploy/kamal.yml

# Setup the application (creates network, volumes, etc.)
kamal setup -c config/deploy/kamal.yml
```

### 3. Deploy Application

```bash
# Deploy all services
kamal deploy -c config/deploy/kamal.yml

# Deploy only the main Rails app
kamal app deploy -c config/deploy/kamal.yml

# Deploy specific accessories
kamal accessory boot db -c config/deploy/kamal.yml
kamal accessory boot redis -c config/deploy/kamal.yml
kamal accessory boot skybeam -c config/deploy/kamal.yml
kamal accessory boot skytorch -c config/deploy/kamal.yml
kamal accessory boot skywire -c config/deploy/kamal.yml
```

### 4. Database Setup

```bash
# Run database migrations
kamal app exec "bin/rails db:migrate" -c config/deploy/kamal.yml

# Seed database (if needed)
kamal app exec "bin/rails db:seed" -c config/deploy/kamal.yml
```

### 4. Verify Deployment

```bash
# Check application status
kamal app details

# View logs
kamal app logs

# Check all services
kamal accessory details db
kamal accessory details redis
kamal accessory details skybeam
kamal accessory details skytorch
kamal accessory details skywire
```

## Common Commands

### Application Management

```bash
# View application details
kamal app details

# View logs
kamal app logs -f

# Open Rails console
kamal app console

# Open shell
kamal app shell

# Open database console
kamal app dbc

# Restart application
kamal app restart
```

### Accessory Management

```bash
# View accessory details
kamal accessory details <name>

# View accessory logs
kamal accessory logs <name> -f

# Restart accessory
kamal accessory restart <name>

# Stop accessory
kamal accessory stop <name>

# Remove accessory (WARNING: This will delete data volumes)
kamal accessory remove <name>
```

### Maintenance

```bash
# Remove old container images
kamal app prune

# View server information
kamal server exec "docker ps"
kamal server exec "docker network ls"
kamal server exec "docker volume ls"
```

## Service URLs

Within the Docker network, services communicate via:
- **feedbrainer**: `http://news-web:3000`
- **skybeam**: `http://news-skybeam:4000`
- **skytorch**: `http://news-skytorch:5000`
- **skywire**: `http://news-skywire:6000`
- **PostgreSQL**: `news-db:5432`
- **Redis**: `news-redis:6379`

External access:
- **feedbrainer**: `https://open.news` (via Traefik proxy)
- **skybeam**: `http://164.90.132.64:4000` (localhost only)
- **skytorch**: `http://164.90.132.64:5000` (localhost only)
- **skywire**: `http://164.90.132.64:6000` (localhost only)

## Troubleshooting

### Connection Issues

```bash
# Test SSH connection
ssh deploy@164.90.132.64

# Test Docker access
kamal server exec "docker ps"
```

### Service Not Starting

```bash
# Check service logs
kamal accessory logs <name> -f

# Check service status
kamal accessory details <name>

# Restart service
kamal accessory restart <name>
```

### Database Issues

```bash
# Check database connection
kamal app exec "bin/rails db:version"

# Check database logs
kamal accessory logs db -f

# Access database directly
kamal accessory exec db "psql -U feedbrainer -d feedbrainer_production"
```

### Network Issues

```bash
# Check Docker network
kamal server exec "docker network inspect news-app"

# Verify services can communicate
kamal app exec "curl http://news-skybeam:4000/health"
```

## Removing Old Deployment

If you need to remove the old `feedbrainer` deployment:

```bash
# Stop and remove old containers
kamal server exec "docker ps -a | grep feedbrainer"
kamal server exec "docker stop <container-id>"
kamal server exec "docker rm <container-id>"

# Remove old volumes (WARNING: This deletes data)
kamal server exec "docker volume ls | grep feedbrainer"
kamal server exec "docker volume rm <volume-name>"
```

## Environment Variables

All environment variables are configured in `config/deploy/kamal.yml`. Key variables:

- `RAILS_ENV`: `production`
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `SKYBEAM_URL`, `SKYTORCH_URL`, `SKYWIRE_URL`: Cross-service URLs

Secrets are loaded from `.kamal/secrets`.

## SSL Certificate

SSL is automatically configured via Let's Encrypt through Kamal's Traefik proxy. The certificate is automatically renewed.

## Volumes

Persistent volumes:
- `db_data`: PostgreSQL data
- `redis_data`: Redis persistence
- `feedbrainer_storage`: Rails Active Storage

## Backup Recommendations

1. **Database**: Regularly backup PostgreSQL data volume
2. **Redis**: Consider persistence configuration
3. **Active Storage**: Backup `feedbrainer_storage` volume

## Monitoring

Monitor services using:
- `kamal app logs -f` - Application logs
- `kamal accessory logs <name> -f` - Accessory logs
- Server monitoring tools (optional)

## Rollback

To rollback to a previous version:

```bash
# List available versions
kamal app versions

# Rollback to specific version
kamal app rollback [version]
```

## Additional Resources

- [Kamal Documentation](https://kamal-deploy.org/)
- [Docker Documentation](https://docs.docker.com/)
- Project-specific documentation in `docs/` directory

