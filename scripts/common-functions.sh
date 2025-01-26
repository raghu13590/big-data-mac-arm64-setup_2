#!/bin/bash

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to get the current timestamp
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Function to check if a container is running
is_running() {
    docker inspect --format="{{.State.Running}}" "$1" 2>/dev/null | grep "true" > /dev/null
}

# Function to verify if a container started successfully and is healthy
verify_service() {
    local service_name="$1"
    local max_retries=10
    local retries=0

    if is_running "$service_name"; then
        echo -e "\n$(timestamp) [INFO] $service_name started successfully."
    else
        echo -e "\n$(timestamp) [ERROR] Failed to start $service_name. Exiting."
        exit 1
    fi

    # Wait for the service to become healthy
    while [ $retries -lt $max_retries ]; do
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$service_name" 2>/dev/null)
        if [ "$health_status" == "healthy" ]; then
            echo "$(timestamp) [INFO] $service_name is healthy."
            return 0
        elif [ "$health_status" == "unhealthy" ]; then
            echo "$(timestamp) [ERROR] $service_name is unhealthy. Checking logs..."
            docker logs "$service_name"
            exit 1
        elif [ -z "$health_status" ]; then
            echo "$(timestamp) [WARN] $service_name does not have a health check defined."
            return 0
        else
            # Only print the initial unknown status message and then wait without additional output
            if [ $retries -eq 0 ]; then
                echo "$(timestamp) [INFO] Waiting for $service_name to become healthy..."
            fi
            sleep 10
        fi
        retries=$((retries+1))
    done

    echo "$(timestamp) [ERROR] $service_name did not become healthy within the expected time. Checking logs..."
    docker logs "$service_name"
    exit 1
}

# Function to remove orphan containers
remove_orphan_containers() {
    local project_name="$1"
    local orphan_containers=$(docker ps -a --filter "label=com.docker.compose.project=$project_name" --filter "status=exited" --format "{{.ID}}")

    if [ ! -z "$orphan_containers" ]; then
        echo -e "\n$(timestamp) [INFO] Removing orphan containers..."
        docker rm $orphan_containers
    fi
}

# Function to create Docker network if it doesn't exist
create_network_if_not_exists() {
    local network_name="$1"

    if ! docker network ls | grep -w "$network_name" > /dev/null; then
        echo -e "\n$(timestamp) [INFO] Creating Docker network $network_name..."
        docker network create "$network_name"
    fi
}

# Function to extract the network name from Docker Compose file
get_network_name() {
    local compose_file="$1"
    local service_name="$2"
    local network_name=$(docker-compose -f "$compose_file" config | awk -v service="$service_name" '
    $0 ~ "services:" { in_services=1 }
    in_services && $0 ~ service { in_service=1 }
    in_service && $0 ~ "networks:" { getline; gsub(":", "", $1); print $1; exit }
    ')
    echo "$network_name"
}

# Function to validate Docker Compose file
validate_compose_file() {
    local compose_file="$1"
    if ! docker-compose -f "$compose_file" config > /dev/null; then
        echo -e "\n$(timestamp) [ERROR] Invalid Docker Compose file: $compose_file"
        exit 1
    fi
}

# Function to check if Docker is running
check_docker_running() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "\n$(timestamp) [ERROR] Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to restart a container if it's not running
restart_service() {
    local service_name="$1"
    local compose_file="$2"
    local service_container="$3"
    local dependent_service_name="$4"
    local project_name=$(docker-compose -f "$compose_file" config --services | head -n 1)

    check_docker_running
    validate_compose_file "$compose_file"

    # Extract network name from Docker Compose file
    local network_name=$(get_network_name "$compose_file" "$service_name")
    local dependent_network_name=$(get_network_name "$compose_file" "$dependent_service_name")

    # Check if service and dependent service are on the same network
    if [ "$network_name" != "$dependent_network_name" ]; then
        echo -e "\n$(timestamp) [ERROR] $service_name and $dependent_service_name are not on the same network."
        exit 1
    fi

    # Ensure the network exists
    create_network_if_not_exists "$network_name"

    # Remove orphan containers
    remove_orphan_containers "$project_name"

    if is_running "$service_container"; then
        echo -e "\n$(timestamp) [INFO] $service_name is already running."
    else
        echo -e "\n$(timestamp) [INFO] Starting $service_name..."
        docker-compose -f "$compose_file" up -d "$service_name"
        verify_service "$service_container"
    fi
}