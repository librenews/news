#!/bin/bash
# Script to run on the server to build skybeam
# Copy this to the server and run it there

set -e

REGISTRY_USER="${REGISTRY_USER:-librenews}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-dckr_pat_Bwm9yUZFhXpTNMtDbW0tRecA1zw}"

echo "Logging in to Docker Hub..."
echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USER" --password-stdin

echo "Building skybeam..."
docker build -f docker/skybeam/Dockerfile --target production -t "$REGISTRY_USER/skybeam:latest" .

echo "Pushing skybeam..."
docker push "$REGISTRY_USER/skybeam:latest"

echo "Skybeam built and pushed successfully!"

