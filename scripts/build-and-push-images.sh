#!/bin/bash
# Build and push custom service images to Docker Hub
# Run this before deploying with Kamal

set -e

REGISTRY_USER="${REGISTRY_USER:-lbrenews}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"

if [ -z "$REGISTRY_PASSWORD" ]; then
  echo "Error: REGISTRY_PASSWORD environment variable is required"
  echo "You can get this from .kamal/secrets (KAMAL_REGISTRY_PASSWORD)"
  exit 1
fi

echo "Logging in to Docker Hub..."
echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USER" --password-stdin

echo "Building and pushing skybeam..."
docker build -f docker/skybeam/Dockerfile --target production -t "$REGISTRY_USER/skybeam:latest" .
docker push "$REGISTRY_USER/skybeam:latest"

echo "Building and pushing skytorch..."
docker build -f docker/skytorch/Dockerfile --target production -t "$REGISTRY_USER/skytorch:latest" .
docker push "$REGISTRY_USER/skytorch:latest"

echo "Building and pushing skywire..."
docker build -f docker/skywire/Dockerfile --target production -t "$REGISTRY_USER/skywire:latest" .
docker push "$REGISTRY_USER/skywire:latest"

echo "All images built and pushed successfully!"
echo ""
echo "You can now run: kamal setup -c config/deploy/kamal.yml"

