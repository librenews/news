#!/bin/bash
# Build skybeam on the server
# Run this on the server: ssh deploy@164.90.132.64

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

echo "Building skybeam for linux/amd64..."
docker build -f docker/skybeam/Dockerfile --target production -t "$REGISTRY_USER/skybeam:latest" .

echo "Pushing skybeam..."
docker push "$REGISTRY_USER/skybeam:latest"

echo "Skybeam built and pushed successfully!"
