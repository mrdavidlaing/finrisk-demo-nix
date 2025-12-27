#!/usr/bin/env bash
# Script to clear the Dependency Track PostgreSQL database
#
# Usage:
#   ./clear-db.sh
#
# This script will:
#   1. Connect to the PostgreSQL container
#   2. Drop and recreate the database (or truncate all tables)
#   3. Dependency Track will recreate the schema on next startup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="compliance/dependency-track/docker-compose.yml"
DB_NAME="dtrack"
DB_USER="dtrack"
DB_PASSWORD="dtrack"
POSTGRES_SERVICE="postgres"

echo -e "${BLUE}Clearing Dependency Track PostgreSQL database...${NC}"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker-compose or docker is required${NC}" >&2
    exit 1
fi

# Use docker compose (v2) if available, otherwise docker-compose (v1)
if command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose -f ${COMPOSE_FILE}"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose -f ${COMPOSE_FILE}"
else
    echo -e "${RED}Error: docker compose or docker-compose is required${NC}" >&2
    exit 1
fi

# Check if the postgres container is running
if ! $COMPOSE_CMD ps | grep -q "${POSTGRES_SERVICE}.*Up"; then
    echo -e "${YELLOW}Warning: PostgreSQL container is not running${NC}"
    echo -e "${BLUE}Starting PostgreSQL container...${NC}"
    $COMPOSE_CMD up -d ${POSTGRES_SERVICE}
    echo -e "${BLUE}Waiting for PostgreSQL to be ready...${NC}"
    sleep 5
fi

echo -e "${BLUE}Connecting to PostgreSQL and clearing database...${NC}"

# Method 1: Drop and recreate the database (cleanest)
# This requires connecting to the default 'postgres' database first
$COMPOSE_CMD exec -T ${POSTGRES_SERVICE} psql -U ${DB_USER} -d postgres <<EOF
-- Terminate all connections to the dtrack database
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = '${DB_NAME}'
  AND pid <> pg_backend_pid();

-- Drop the database
DROP DATABASE IF EXISTS ${DB_NAME};

-- Recreate the database
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database cleared successfully${NC}"
    echo -e "${BLUE}Note: Dependency Track will recreate the schema automatically on next startup${NC}"
    echo -e "${YELLOW}You may need to restart the Dependency Track API server:${NC}"
    echo -e "  $COMPOSE_CMD restart apiserver"
else
    echo -e "${RED}✗ Failed to clear database${NC}" >&2
    exit 1
fi

