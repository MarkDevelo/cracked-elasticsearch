#!/bin/bash
set -e # Exit on error

if  [ ! "$1" ] ;then
    echo "You have not entered a version"
    exit 1
fi
version=$1
echo -e "\033[36mRun for version: ${version}\033[0m"

service_name="elastic-crack-builder" # Renamed to avoid conflict with actual service

# Stop and remove any previous builder container if it exists
docker ps -a --filter "name=${service_name}" --format "{{.ID}}" | xargs -r docker stop
docker ps -a --filter "name=${service_name}" --format "{{.ID}}" | xargs -r docker rm

# Build the cracking image
docker build --no-cache -f Dockerfile \
--build-arg VERSION="${version}" \
--tag ${service_name}-img:${version} . # Tag the image differently

# Run the cracking container
# It will create an 'output' directory inside this script's CWD
# (i.e., crack-builder/output)
echo "Running crack process in container..."
docker run --name ${service_name} --rm \
-v "$(pwd)/output:/crack/output" \
${service_name}-img:${version}

echo "Cracking process finished. Output in $(pwd)/output"