#!/bin/bash
set -e

SERVER_USER="deploy"
SERVER_HOST="164.90.132.64"
REMOTE_DIR="~/skybeam-build"
REGISTRY_USER="${REGISTRY_USER:-librenews}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"

if [ -z "$REGISTRY_PASSWORD" ]; then
  echo "Error: REGISTRY_PASSWORD environment variable is required"
  echo "You can get this from .kamal/secrets (KAMAL_REGISTRY_PASSWORD)"
  exit 1
fi

echo "Syncing files to $SERVER_USER@$SERVER_HOST:$REMOTE_DIR..."
# Create remote dir if it doesn't exist
ssh "$SERVER_USER@$SERVER_HOST" "mkdir -p $REMOTE_DIR"

# Sync necessary files/folders
# We exclude heavy/unnecessary folders like _build, deps, .git
rsync -avz --delete \
  --exclude '.git' \
  --exclude '_build' \
  --exclude 'deps' \
  --exclude 'node_modules' \
  --exclude 'priv/static' \
  skybeam \
  docker \
  config \
  "$SERVER_USER@$SERVER_HOST:$REMOTE_DIR/"

echo "Starting remote build on $SERVER_HOST..."
ssh "$SERVER_USER@$SERVER_HOST" "cd $REMOTE_DIR && \
  echo '$REGISTRY_PASSWORD' | docker login -u '$REGISTRY_USER' --password-stdin && \
  docker build -f docker/skybeam/Dockerfile --target production -t '$REGISTRY_USER/skybeam:latest' . && \
  docker push '$REGISTRY_USER/skybeam:latest'"

echo "Skybeam built and pushed successfully from server!"
