#!/bin/bash

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
    printf "${YELLOW}Stopping container: ${CONTAINER_NAME}...${NC}\n"
    docker stop "${CONTAINER_NAME}"

    printf "${YELLOW}Removing container: ${CONTAINER_NAME}...${NC}\n"
    docker rm "${CONTAINER_NAME}"

    printf "${GREEN}✅ Container removed successfully.${NC}\n"
else
    printf "${RED}⚠️  Container ${CONTAINER_NAME} not found.${NC}\n"
fi

# 🗑️ Step 2: Remove the Docker Image
if docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
    printf "${YELLOW}Removing image: ${IMAGE_NAME}...${NC}\n"
    docker rmi "${IMAGE_NAME}"

    printf "${GREEN}✅ Image removed successfully.${NC}\n"
else
    printf "${RED}⚠️  Image ${IMAGE_NAME} not found.${NC}\n"
fi

# 🚮 Step 3: Clean Up Dangling Images (Optional)
if [ "$(docker images -f 'dangling=true' -q)" ]; then
    printf "${YELLOW}Cleaning up dangling Docker images...${NC}\n"
    docker image prune -f
    printf "${GREEN}✅ Dangling images cleaned up.${NC}\n"
fi


# delete ./docker directory

rm -rf ./docker

# 🎯 Final Message
printf "${GREEN}✅ Cleanup complete. Docker environment is clean.${NC}\n"
printf "${GREEN}✅ ./docker deleted. ${NC}\n"
