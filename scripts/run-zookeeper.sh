#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SCRIPT_DIR/common-functions.sh"

# Define the path to the Docker Compose file
COMPOSE_FILE="$SCRIPT_DIR/../docker-compose.yml"

# Create directories if they do not exist
mkdir -p "$SCRIPT_DIR/../app-data/zookeeper/zookeeper1/data"
mkdir -p "$SCRIPT_DIR/../app-data/zookeeper/zookeeper2/data"
mkdir -p "$SCRIPT_DIR/../app-data/zookeeper/zookeeper3/data"

# Create the myid files
echo "1" > "$SCRIPT_DIR/../app-data/zookeeper/zookeeper1/data/myid"
echo "2" > "$SCRIPT_DIR/../app-data/zookeeper/zookeeper2/data/myid"
echo "3" > "$SCRIPT_DIR/../app-data/zookeeper/zookeeper3/data/myid"

# Verify the myid files are created
if [ ! -f "$SCRIPT_DIR/../app-data/zookeeper/zookeeper1/data/myid" ]; then
  echo "Error: myid file for zookeeper1 was not created."
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/../app-data/zookeeper/zookeeper2/data/myid" ]; then
  echo "Error: myid file for zookeeper2 was not created."
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/../app-data/zookeeper/zookeeper3/data/myid" ]; then
  echo "Error: myid file for zookeeper3 was not created."
  exit 1
fi

# Restart Zookeeper if it's not running
docker-compose -f "$COMPOSE_FILE" up -d zookeeper1 zookeeper2 zookeeper3

# Check the status of the Zookeeper instances
echo "Checking Zookeeper cluster status..."
sleep 10
docker exec -it zookeeper1 zkServer.sh status
docker exec -it zookeeper2 zkServer.sh status
docker exec -it zookeeper3 zkServer.sh status

# Print AdminServer URLs
echo "Zookeeper AdminServer URLs:"
echo "Zookeeper1: http://localhost:8081/commands"
echo "Zookeeper2: http://localhost:8082/commands"
echo "Zookeeper3: http://localhost:8083/commands"
