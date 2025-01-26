#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SCRIPT_DIR/common-functions.sh"

# Define the path to the Docker Compose file
COMPOSE_FILE="$SCRIPT_DIR/../docker-compose.yml"

# Create directories and myid files for each Zookeeper instance
for i in {1..3}; do
  instance_dir="$SCRIPT_DIR/../app-data/zookeeper/zookeeper$i/data"
  myid_file="$instance_dir/myid"

  # Create the directory if it does not exist
  mkdir -p "$instance_dir"

  # Create the myid file with the instance ID
  echo "$i" > "$myid_file"

  # Verify the myid file was created
  if [ ! -f "$myid_file" ]; then
    echo "Error: myid file for zookeeper$i was not created."
    exit 1
  fi
done

# Restart Zookeeper cluster in simultaneous mode
echo -e "\nStarting Zookeeper cluster..."
START_MODE=simultaneous restart_service "$COMPOSE_FILE" "zookeeper1" "zookeeper2" "zookeeper3"

# Wait for the cluster to stabilize
echo -e "\nWaiting for Zookeeper cluster to stabilize..."
sleep 20

# Function to validate Zookeeper instance
validate_zookeeper_instance() {
  local container_name=$1
  local admin_url=$2

  echo -e "\nValidating $container_name..."

  # Check the status of the Zookeeper instance
  echo "Checking status of $container_name..."
  if ! docker exec -it "$container_name" zkServer.sh status | grep -E "Client port found|Mode"; then
    echo "Error: $container_name is not healthy."
    exit 1
  fi

  # Check if the AdminServer is accessible
  echo "Checking AdminServer for $container_name..."
  if ! curl -sSf "$admin_url" > /dev/null; then
    echo "Error: AdminServer for $container_name is not accessible."
    exit 1
  fi

  echo "$container_name is running and healthy."
}

# Validate each Zookeeper instance
validate_zookeeper_instance "zookeeper1" "http://localhost:8081/commands"
validate_zookeeper_instance "zookeeper2" "http://localhost:8082/commands"
validate_zookeeper_instance "zookeeper3" "http://localhost:8083/commands"

# Print AdminServer URLs
echo -e "\nZookeeper AdminServer URLs:"
echo "Zookeeper1: http://localhost:8081/commands"
echo "Zookeeper2: http://localhost:8082/commands"
echo "Zookeeper3: http://localhost:8083/commands"

echo "Zookeeper cluster is running and healthy!"