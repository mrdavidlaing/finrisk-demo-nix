#!/usr/bin/env bash
# Script to upload SBOMs to OWASP Dependency Track
#
# Usage:
#   ./scripts/upload-sboms-to-dtrack.sh
#
# Environment variables:
#   DEPENDENCY_TRACK_API_KEY (required) - API key for Dependency Track
#   DEPENDENCY_TRACK_URL (optional) - Base URL for Dependency Track API (default: http://localhost:8081)
#
# The script will:
#   1. Get version from git describe
#   2. Upload all Syft SBOMs (compliance/sboms/*.cdx.json)
#   3. Upload all Nix SBOMs (compliance/sboms/nix/*.cdx.json)
#
# Exit codes:
#   0 - Success
#   1 - Error occurred

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DT_URL="${DEPENDENCY_TRACK_URL:-http://localhost:8081}"
DT_API_KEY="${DEPENDENCY_TRACK_API_KEY:-}"

# Validate API key
if [ -z "$DT_API_KEY" ]; then
    echo -e "${RED}Error: DEPENDENCY_TRACK_API_KEY environment variable is required${NC}" >&2
    echo "Get your API key from Dependency Track UI: Administration > Access Management > API Keys" >&2
    exit 1
fi

# Get version from git describe
VERSION=$(git describe --tags --always 2>/dev/null || echo "unknown")
echo -e "${BLUE}Using version: ${VERSION}${NC}"

# Validate Dependency Track is reachable
echo -e "${BLUE}Checking Dependency Track connectivity...${NC}"
if ! curl -sf -H "X-Api-Key: ${DT_API_KEY}" "${DT_URL}/api/version" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot reach Dependency Track at ${DT_URL}${NC}" >&2
    echo "Make sure Dependency Track is running (e.g., docker-compose up -d in services/dependency-track/)" >&2
    exit 1
fi
echo -e "${GREEN}✓ Dependency Track is reachable${NC}"

# Function to upload a single SBOM
upload_sbom() {
    local sbom_file="$1"
    local project_name="$2"
    local project_version="$3"
    
    if [ ! -f "$sbom_file" ]; then
        echo -e "${YELLOW}  ⚠ Skipping ${sbom_file} (file not found)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}  Uploading ${project_name} (${project_version})...${NC}"
    
    # Upload using curl with autoCreate enabled
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "${DT_URL}/api/v1/bom" \
        -H "X-Api-Key: ${DT_API_KEY}" \
        -F "projectName=${project_name}" \
        -F "projectVersion=${project_version}" \
        -F "autoCreate=true" \
        -F "bom=@${sbom_file}")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo -e "${GREEN}  ✓ Successfully uploaded ${project_name}${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to upload ${project_name} (HTTP ${http_code})${NC}" >&2
        if [ -n "$body" ]; then
            echo -e "${RED}    Response: ${body}${NC}" >&2
        fi
        return 1
    fi
}

# Track upload results
UPLOADED=0
FAILED=0
SKIPPED=0

# Upload Syft SBOMs (container/runtime dependencies)
echo ""
echo -e "${BLUE}Uploading Syft SBOMs (container dependencies)...${NC}"
SERVICES="api-gateway kyc-service fee-service sanctions-service swift-gateway crypto-transfer audit-service web-portal smoke-tests"

for service in $SERVICES; do
    sbom_file="compliance/sboms/${service}.cdx.json"
    if [ -f "$sbom_file" ]; then
        if upload_sbom "$sbom_file" "$service" "$VERSION"; then
            UPLOADED=$((UPLOADED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${YELLOW}  ⚠ Skipping ${service} (SBOM not found)${NC}"
        SKIPPED=$((SKIPPED + 1))
    fi
done

# Upload Nix SBOMs (build-time dependencies)
echo ""
echo -e "${BLUE}Uploading Nix SBOMs (build-time dependencies)...${NC}"

for service in $SERVICES; do
    sbom_file="compliance/sboms/nix/${service}.cdx.json"
    project_name="${service}-nix"
    if [ -f "$sbom_file" ]; then
        if upload_sbom "$sbom_file" "$project_name" "$VERSION"; then
            UPLOADED=$((UPLOADED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${YELLOW}  ⚠ Skipping ${project_name} (SBOM not found)${NC}"
        SKIPPED=$((SKIPPED + 1))
    fi
done

# Summary
echo ""
echo -e "${BLUE}Upload Summary:${NC}"
echo -e "  ${GREEN}✓ Uploaded: ${UPLOADED}${NC}"
if [ $SKIPPED -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Skipped: ${SKIPPED}${NC}"
fi
if [ $FAILED -gt 0 ]; then
    echo -e "  ${RED}✗ Failed: ${FAILED}${NC}"
    exit 1
fi

echo -e "${GREEN}All SBOMs uploaded successfully!${NC}"
exit 0

