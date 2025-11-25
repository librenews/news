#!/bin/bash
# Build and push custom service images to Docker Hub
# Run this before deploying with Kamal

set -e

REGISTRY_USER="${REGISTRY_USER:-librenews}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"

if [ -z "$REGISTRY_PASSWORD" ]; then
  echo "Error: REGISTRY_PASSWORD environment variable is required"
  echo "You can get this from .kamal/secrets (KAMAL_REGISTRY_PASSWORD)"
  exit 1
fi

echo "Logging in to Docker Hub..."
echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USER" --password-stdin

echo "Building and pushing skybeam..."
# Note: skybeam builds on the server to avoid cross-compilation issues
./scripts/build-skybeam-remote.sh

echo "Building and pushing skytorch..."
docker buildx build --platform linux/amd64 -f docker/skytorch/Dockerfile --target production -t "$REGISTRY_USER/skytorch:latest" --push .

echo "Building and pushing skywire..."
docker buildx build --platform linux/amd64 -f docker/skywire/Dockerfile --target production -t "$REGISTRY_USER/skywire:latest" --push .

echo "All images built and pushed successfully!"
echo ""
echo "You can now run: kamal setup -c config/deploy/kamal.yml"

