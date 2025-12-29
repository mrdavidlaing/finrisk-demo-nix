#!/usr/bin/env bash
# Dependency Track Management Script
# Usage: ./dt-manage.sh <command> [options]

set -euo pipefail

# Script directory - supports being called from anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
ENV_FILE="${SCRIPT_DIR}/.dtrack.env"
DT_URL="${DEPENDENCY_TRACK_URL:-http://localhost:8081}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Command: start
cmd_start() {
    echo -e "${BLUE}Starting Dependency Track...${NC}"

    # Start containers
    docker compose -f "${COMPOSE_FILE}" up -d

    # Wait for health checks (120 second timeout)
    echo -e "${BLUE}Waiting for services to be healthy...${NC}"
    timeout 120 bash -c 'until curl -sf http://localhost:8081/api/version > /dev/null 2>&1; do sleep 2; done'

    # Handle API key setup
    if [ -f "${ENV_FILE}" ]; then
        source "${ENV_FILE}"
        if curl -sf -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" "${DT_URL}/api/version" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Dependency Track is running${NC}"
            show_urls
            return 0
        else
            echo -e "${YELLOW}⚠ API key in .dtrack.env is invalid${NC}"
            rm "${ENV_FILE}"
        fi
    fi

    # Prompt for new API key
    echo ""
    echo -e "${BLUE}=== Initial Setup Required ===${NC}"
    echo "1. Open http://localhost:8080 in your browser"
    echo "2. Login with: admin / admin"
    echo "3. Navigate to: Administration > Access Management > Teams > Administrator > API Keys"
    echo "4. Copy to key and paste it below"
    echo ""
    read -p "Enter your API key: " api_key

    # Save API key with secure permissions
    echo "DEPENDENCY_TRACK_API_KEY=$api_key" > "${ENV_FILE}"
    chmod 600 "${ENV_FILE}"

    # Verify API key
    if curl -sf -H "X-Api-Key: $api_key" "${DT_URL}/api/version" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API key saved and verified${NC}"
        show_urls
    else
        echo -e "${RED}✗ API key verification failed${NC}"
        rm "${ENV_FILE}"
        exit 1
    fi
}

# Command: stop
cmd_stop() {
    echo -e "${BLUE}Stopping Dependency Track...${NC}"
    docker compose -f "${COMPOSE_FILE}" down
    echo -e "${GREEN}✓ Stopped${NC}"
}

# Command: reset (delete all projects)
cmd_reset() {
    # Load API key
    if [ ! -f "${ENV_FILE}" ]; then
        echo -e "${RED}Error: .dtrack.env not found${NC}"
        echo "Run './dt-manage.sh start' to set up Dependency Track"
        exit 1
    fi
    source "${ENV_FILE}"

    # Get projects
    echo -e "${BLUE}Fetching projects...${NC}"
    projects=$(curl -s -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" \
        "${DT_URL}/api/v1/project" 2>/dev/null || echo "[]")

    count=$(echo "$projects" | jq '. | length')

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No projects found. Nothing to delete.${NC}"
        exit 0
    fi

    echo -e "${BLUE}Found $count project(s):${NC}"
    echo "$projects" | jq -r '.[] | "  - \(.name) (\(.version))"'
    echo ""

    # Confirm deletion
    read -p "Delete all $count projects? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    # Delete projects
    echo -e "${BLUE}Deleting projects...${NC}"
    deleted=0
    for uuid in $(echo "$projects" | jq -r '.[].uuid'); do
        if curl -s -X DELETE -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" \
            "${DT_URL}/api/v1/project/${uuid}" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Deleted: $uuid"
            ((deleted++)) || true
        else
            echo -e "  ${RED}✗${NC} Failed to delete: $uuid"
        fi
    done

    echo ""
    echo -e "${GREEN}✓ Reset complete ($deleted projects deleted)${NC}"
    echo -e "  Teams, API keys, and configuration are preserved${NC}"
}

# Command: status
cmd_status() {
    echo -e "${BLUE}Dependency Track Status${NC}"
    echo -e "${BLUE}=======================${NC}"

    # Check containers
    echo ""
    echo "Containers:"
    if docker compose -f "${COMPOSE_FILE}" ps | grep -q "Up"; then
        echo -e "  ${GREEN}✓${NC} Running"
    else
        echo -e "  ${RED}✗${NC} Not running"
    fi

    # Check API key
    echo ""
    echo "API Key:"
    if [ -f "${ENV_FILE}" ]; then
        source "${ENV_FILE}"
        if curl -sf -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" \
            "${DT_URL}/api/version" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Valid"
        else
            echo -e "  ${RED}✗${NC} Invalid (stored in .dtrack.env)"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Not configured"
    fi

    # Show projects
    echo ""
    echo "Projects:"
    if [ -f "${ENV_FILE}" ]; then
        source "${ENV_FILE}"
        count=$(curl -s -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" \
            "${DT_URL}/api/v1/project" 2>/dev/null | jq '. | length' || echo "?")
        echo "  $count project(s)"
    else
        echo "  (API key not configured)"
    fi

    # Show URLs
    show_urls
}

# Command: clean (factory reset)
cmd_clean() {
    echo -e "${BLUE}Factory Reset Dependency Track${NC}"
    echo -e "${YELLOW}This will delete ALL data:${NC}"
    echo "  - All projects"
    echo "  - API keys"
    echo "  - User accounts"
    echo "  - Database contents and volumes"
    echo ""

    read -p "Confirm factory reset? [yes/NO] " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi

    # Stop and remove volumes
    echo -e "${BLUE}Stopping containers and removing volumes...${NC}"
    docker compose -f "${COMPOSE_FILE}" down -v

    # Remove API key file
    if [ -f "${ENV_FILE}" ]; then
        rm "${ENV_FILE}"
        echo -e "${GREEN}✓${NC} Removed .dtrack.env"
    fi

    echo ""
    echo -e "${GREEN}✓ Factory reset complete${NC}"
    echo "  Run './dt-manage.sh start' to set up a fresh instance"
}

# Command: scan-vulnerabilities
cmd_scan_vulnerabilities() {
    # Load API key
    if [ ! -f "${ENV_FILE}" ]; then
        echo -e "${RED}Error: .dtrack.env not found${NC}"
        echo "Run './dt-manage.sh start' to set up Dependency Track"
        exit 1
    fi
    source "${ENV_FILE}"

    # Check if running
    if ! docker compose -f "${COMPOSE_FILE}" ps | grep -q "Up"; then
        echo -e "${RED}Error: Dependency Track is not running${NC}"
        echo "Run './dt-manage.sh start' to start it"
        exit 1
    fi

    # Get projects
    echo -e "${BLUE}Triggering vulnerability analysis...${NC}"
    projects=$(curl -s -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" \
        "${DT_URL}/api/v1/project" 2>/dev/null || echo "[]")

    count=$(echo "$projects" | jq '. | length')

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No projects found. Nothing to scan.${NC}"
        exit 0
    fi

    echo -e "${BLUE}Found $count project(s)${NC}"
    echo -e "${BLUE}Note: Re-uploading SBOMs triggers immediate vulnerability analysis${NC}"
    echo ""

    # Re-upload SBOMs to trigger analysis
    scanned=0
    failed=0
    for uuid in $(echo "$projects" | jq -r '.[].uuid'); do
        name=$(echo "$projects" | jq -r ".[] | select(.uuid == \"$uuid\") | .name")
        version=$(echo "$projects" | jq -r ".[] | select(.uuid == \"$uuid\") | .version")
        sbom_file="${SCRIPT_DIR}/../sboms/container-${name}.cdx.json"
        echo -e "${BLUE}Scanning: ${name}...${NC}"

        if [ ! -f "$sbom_file" ]; then
            echo -e "  ${YELLOW}⚠${NC} SBOM not found: $sbom_file"
            ((failed++)) || true
            continue
        fi

        # Upload SBOM (this triggers analysis)
        response=$(curl -s -w "\n%{http_code}" \
            -X POST "${DT_URL}/api/v1/bom" \
            -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" \
            -F "project=${uuid}" \
            -F "bom=@${sbom_file}")

        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')

        if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
            echo -e "  ${GREEN}✓${NC} Analysis triggered (HTTP ${http_code})"
            ((scanned++)) || true
        else
            echo -e "  ${RED}✗${NC} Failed (HTTP ${http_code})"
            ((failed++)) || true
        fi
    done

    echo ""
    echo -e "${BLUE}Scan Summary:${NC}"
    echo -e "  ${GREEN}✓${NC} Scanned: ${scanned}"
    if [ $failed -gt 0 ]; then
        echo -e "  ${RED}✗${NC} Failed: ${failed}"
    fi
    echo ""
    echo -e "${BLUE}Note: Analysis runs asynchronously${NC}"
    echo -e "  Results appear in UI at http://localhost:8080"
    echo ""
    echo -e "${YELLOW}⚠${NC} Ensure vulnerability sources are enabled:"
    echo -e "  UI > Administration > Vulnerability Sources > NVD / OSS Index / etc.${NC}"
}

# Command: logs
cmd_logs() {
    # Check for -f flag in arguments
    local follow=false
    for arg in "$@"; do
        if [ "$arg" = "-f" ]; then
            follow=true
            break
        fi
    done
    
    # Check if running
    if ! docker compose -f "${COMPOSE_FILE}" ps | grep -q "Up"; then
        echo -e "${RED}Error: Dependency Track is not running${NC}"
        echo "Run './dt-manage.sh start' to start it"
        exit 1
    fi
    
    echo -e "${BLUE}Showing Dependency Track logs...${NC}"
    if [ "$follow" = "true" ]; then
        echo -e "${BLUE}Press Ctrl+C to stop${NC}"
    fi
    echo ""
    
    if [ "$follow" = "true" ]; then
        docker compose -f "${COMPOSE_FILE}" logs -f
    else
        docker compose -f "${COMPOSE_FILE}" logs
    fi
}

# Helper: show URLs
show_urls() {
    echo ""
    echo -e "${BLUE}Access URLs:${NC}"
    echo "  UI:   http://localhost:8080"
    echo "  API:  http://localhost:8081"
}

# Show usage
show_usage() {
    echo "Usage: ./dt-manage.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start   Start Dependency Track and configure API key"
    echo "  stop    Stop Dependency Track"
    echo "  reset   Delete all projects (preserves config)"
    echo "  status  Show Dependency Track status"
    echo "  scan    Trigger vulnerability analysis for all projects"
    echo "  logs    Show Dependency Track logs (add -f to follow)"
    echo "  clean   Factory reset (removes all data)"
    echo ""
    echo "Environment Variables:"
    echo "  DEPENDENCY_TRACK_URL    API base URL (default: http://localhost:8081)"
}

# Main entry point
case "${1:-}" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    reset)   cmd_reset ;;
    status)  cmd_status ;;
    scan)    cmd_scan_vulnerabilities ;;
    logs)    cmd_logs "$@" ;;
    clean)   cmd_clean ;;
    *)       show_usage ;;
esac
