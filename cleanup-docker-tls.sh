#!/bin/bash
# shellcheck shell=bash
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Docker container and image name
CONTAINER_NAME="nginx-tls-cert"
IMAGE_NAME="nginx-tls-cert"

# 🛑 Step 1: Stop and Remove the Docker Container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  printf "%bStopping container: %s...%b\n" "$YELLOW" "$CONTAINER_NAME" "$NC"
  docker stop "${CONTAINER_NAME}"

  printf "%bRemoving container: %s...%b\n" "$YELLOW" "$CONTAINER_NAME" "$NC"
  docker rm "${CONTAINER_NAME}"

  printf "%b✅ Container removed successfully.%b\n" "$GREEN" "$NC"
else
  printf "%b⚠️  Container %s not found.%b\n" "$RED" "$CONTAINER_NAME" "$NC"
fi

# 🗑️ Step 2: Remove the Docker Image
if docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
  printf "%bRemoving image: %s...%b\n" "$YELLOW" "$IMAGE_NAME" "$NC"
  docker rmi "${IMAGE_NAME}"

  printf "%b✅ Image removed successfully.%b\n" "$GREEN" "$NC"
else
  printf "%b⚠️  Image %s not found.%b\n" "$RED" "$IMAGE_NAME" "$NC"
fi

# 🚮 Step 3: Clean Up Dangling Images (Optional)
if [ "$(docker images -f 'dangling=true' -q)" ]; then
  printf "%bCleaning up dangling Docker images...%b\n" "$YELLOW" "$NC"
  docker image prune -f
  printf "%b✅ Dangling images cleaned up.%b\n" "$GREEN" "$NC"
fi

# Delete ./docker directory
rm -rf ./docker
printf "%b✅ Cleanup complete. Docker environment is clean.%b\n" "$GREEN" "$NC"
printf "%b✅ ./docker deleted.%b\n" "$GREEN" "$NC"
