#!/usr/bin/env bash
# Script to detect dependency changes and regenerate Nix hashes
# This is used in CI to automatically update hashes when Dependabot updates dependencies
#
# Usage:
#   ./scripts/update-nix-hashes.sh
#
# The script will:
#   1. Detect which services have dependency file changes (go.mod, package.json, etc.)
#   2. For each changed service, attempt to regenerate the correct Nix hash
#   3. Update the corresponding .nix file with the new hash
#
# Exit codes:
#   0 - Success (hashes updated or no updates needed)
#   1 - Error occurred

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if any hashes were updated
HASHES_UPDATED=false

# Track which services were updated (for PR comment)
UPDATED_SERVICES=()

# Function to check if a file changed in the PR
file_changed() {
    local pattern="$1"
    if [ "${GITHUB_BASE_REF:-}" != "" ] && [ -n "${GITHUB_BASE_REF}" ]; then
        # In CI, compare against base branch
        # Fetch base branch first
        git fetch origin "${GITHUB_BASE_REF}" --depth=1 2>/dev/null || true
        if git diff --name-only "origin/${GITHUB_BASE_REF}"...HEAD 2>/dev/null | grep -qE "${pattern}"; then
            return 0
        fi
    elif [ "${GITHUB_HEAD_REF:-}" != "" ]; then
        # Alternative: compare HEAD with base
        base_ref="${GITHUB_BASE_REF:-main}"
        git fetch origin "${base_ref}" --depth=1 2>/dev/null || true
        if git diff --name-only "origin/${base_ref}"...HEAD 2>/dev/null | grep -qE "${pattern}"; then
            return 0
        fi
    else
        # Local development, check against main/master
        if git diff --name-only origin/main...HEAD 2>/dev/null | grep -qE "${pattern}"; then
            return 0
        fi
        if git diff --name-only origin/master...HEAD 2>/dev/null | grep -qE "${pattern}"; then
            return 0
        fi
    fi
    return 1
}

# Function to update Go vendorHash
update_go_hash() {
    local service="$1"
    local nix_file="release/${service}.nix"
    
    echo -e "${YELLOW}Updating vendorHash for ${service}...${NC}"
    
    # Backup the file
    cp "$nix_file" "${nix_file}.bak"
    
    # Temporarily set vendorHash to empty string (Nix will compute it)
    sed -i 's/vendorHash = "[^"]*"/vendorHash = ""/' "$nix_file" || \
    sed -i '/vendorHash = /d' "$nix_file"
    
    # Try to build and capture the hash from error message
    build_output=$(nix build ".#${service}" 2>&1 || true)
    
    if echo "$build_output" | grep -q "error: hash mismatch"; then
        # Extract the correct hash from the error message
        new_hash=$(echo "$build_output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1)
        if [ -n "$new_hash" ]; then
            # Update the hash in the file
            if grep -q "vendorHash = \"\"" "$nix_file"; then
                sed -i "s|vendorHash = \"\"|vendorHash = \"${new_hash}\"|" "$nix_file"
            else
                # Add vendorHash after pname line
                sed -i "/pname = \"${service}\";/a\  vendorHash = \"${new_hash}\";" "$nix_file"
            fi
            echo -e "${GREEN}Updated vendorHash for ${service} to ${new_hash}${NC}"
            HASHES_UPDATED=true
            UPDATED_SERVICES+=("${service} (Go - vendorHash)")
            rm -f "${nix_file}.bak"
        else
            # Restore backup if we couldn't extract hash
            mv "${nix_file}.bak" "$nix_file"
            echo -e "${RED}Failed to extract hash for ${service}${NC}"
        fi
    elif echo "$build_output" | grep -q "error"; then
        # Other error, restore backup
        mv "${nix_file}.bak" "$nix_file"
        echo -e "${YELLOW}Build error for ${service}, hash may already be correct or there's another issue${NC}"
    else
        # Build succeeded, hash was already correct
        rm -f "${nix_file}.bak"
        echo -e "${GREEN}Hash for ${service} is already correct${NC}"
    fi
}

# Function to update npm deps hash
update_npm_hash() {
    local service="$1"
    local nix_file="release/${service}.nix"
    
    echo -e "${YELLOW}Updating npmDepsHash for ${service}...${NC}"
    
    # Backup the file
    cp "$nix_file" "${nix_file}.bak"
    
    # Temporarily set npmDepsHash to empty string
    sed -i 's/npmDepsHash = "[^"]*"/npmDepsHash = ""/' "$nix_file" || \
    sed -i '/npmDepsHash = /d' "$nix_file"
    
    # Try to build and capture the hash from error message
    build_output=$(nix build ".#${service}" 2>&1 || true)
    
    if echo "$build_output" | grep -q "error: hash mismatch"; then
        new_hash=$(echo "$build_output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1)
        if [ -n "$new_hash" ]; then
            if grep -q "npmDepsHash = \"\"" "$nix_file"; then
                sed -i "s|npmDepsHash = \"\"|npmDepsHash = \"${new_hash}\"|" "$nix_file"
            else
                sed -i "/pname = \"${service}\";/a\  npmDepsHash = \"${new_hash}\";" "$nix_file"
            fi
            echo -e "${GREEN}Updated npmDepsHash for ${service} to ${new_hash}${NC}"
            HASHES_UPDATED=true
            UPDATED_SERVICES+=("${service} (npm - npmDepsHash)")
            rm -f "${nix_file}.bak"
        else
            mv "${nix_file}.bak" "$nix_file"
            echo -e "${RED}Failed to extract hash for ${service}${NC}"
        fi
    elif echo "$build_output" | grep -q "error"; then
        mv "${nix_file}.bak" "$nix_file"
        echo -e "${YELLOW}Build error for ${service}, hash may already be correct or there's another issue${NC}"
    else
        rm -f "${nix_file}.bak"
        echo -e "${GREEN}Hash for ${service} is already correct${NC}"
    fi
}

# Function to update Maven deps hash
update_maven_hash() {
    local service="$1"
    local nix_file="release/${service}.nix"
    
    echo -e "${YELLOW}Updating outputHash for ${service} Maven dependencies...${NC}"
    
    # Backup the file
    cp "$nix_file" "${nix_file}.bak"
    
    # Comment out the outputHash line
    sed -i 's/^    outputHash = /    # outputHash = /' "$nix_file"
    
    # Try to build and capture the hash from error message
    build_output=$(nix build ".#${service}" 2>&1 || true)
    
    if echo "$build_output" | grep -q "error: hash mismatch"; then
        new_hash=$(echo "$build_output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1)
        if [ -n "$new_hash" ]; then
            # Uncomment and update the hash
            sed -i "s|# outputHash = .*|outputHash = \"${new_hash}\";|" "$nix_file"
            echo -e "${GREEN}Updated outputHash for ${service} to ${new_hash}${NC}"
            HASHES_UPDATED=true
            UPDATED_SERVICES+=("${service} (Maven - outputHash)")
            rm -f "${nix_file}.bak"
        else
            mv "${nix_file}.bak" "$nix_file"
            echo -e "${RED}Failed to extract hash for ${service}${NC}"
        fi
    elif echo "$build_output" | grep -q "error"; then
        mv "${nix_file}.bak" "$nix_file"
        echo -e "${YELLOW}Build error for ${service}, hash may already be correct or there's another issue${NC}"
    else
        # Build succeeded, restore original
        mv "${nix_file}.bak" "$nix_file"
        echo -e "${GREEN}Hash for ${service} is already correct${NC}"
    fi
}

# Function to update Ruby gemset
update_ruby_gemset() {
    local service="$1"
    
    echo -e "${YELLOW}Updating gemset.nix for ${service}...${NC}"
    
    cd "services/${service}"
    
    # Update Gemfile.lock if needed
    if [ -f Gemfile.lock ]; then
        bundle lock --update 2>/dev/null || true
    fi
    
    # Regenerate gemset.nix using bundix
    if command -v bundix &> /dev/null; then
        bundix -l
        if [ -f gemset.nix ]; then
            mv gemset.nix "../../release/${service}-gemset.nix"
            echo -e "${GREEN}Updated gemset.nix for ${service}${NC}"
            HASHES_UPDATED=true
            UPDATED_SERVICES+=("${service} (Ruby - gemset.nix)")
        fi
    elif nix run nixpkgs#bundix -- -l 2>/dev/null; then
        if [ -f gemset.nix ]; then
            mv gemset.nix "../../release/${service}-gemset.nix"
            echo -e "${GREEN}Updated gemset.nix for ${service}${NC}"
            HASHES_UPDATED=true
            UPDATED_SERVICES+=("${service} (Ruby - gemset.nix)")
        fi
    else
        echo -e "${RED}Failed to run bundix for ${service}${NC}"
    fi
    
    cd ../..
}

# Function to update NuGet deps
update_nuget_deps() {
    local service="$1"
    local deps_file="release/${service}-deps.nix"
    
    echo -e "${YELLOW}Updating NuGet dependencies for ${service}...${NC}"
    
    cd "services/${service}"
    
    # Use nuget-to-nix to regenerate the deps file
    if command -v nuget-to-nix &> /dev/null; then
        nuget-to-nix . > "../../${deps_file}"
        echo -e "${GREEN}Updated ${deps_file}${NC}"
        HASHES_UPDATED=true
    elif nix run nixpkgs#nuget-to-nix -- . > "../../${deps_file}" 2>/dev/null; then
        echo -e "${GREEN}Updated ${deps_file}${NC}"
        HASHES_UPDATED=true
        UPDATED_SERVICES+=("${service} (.NET - kyc-service-deps.nix)")
    else
        echo -e "${YELLOW}nuget-to-nix not available, skipping ${service}${NC}"
        echo -e "${YELLOW}You may need to manually update ${deps_file}${NC}"
    fi
    
    cd ../..
}

# Main logic: detect which services have dependency changes
echo -e "${GREEN}Checking for dependency changes...${NC}"

# API Gateway (Go)
if file_changed "services/api-gateway/(go\.mod|go\.sum)"; then
    echo -e "${YELLOW}Detected changes in api-gateway Go dependencies${NC}"
    update_go_hash "api-gateway"
fi

# Web Portal (npm)
if file_changed "services/web-portal/(package\.json|package-lock\.json)"; then
    echo -e "${YELLOW}Detected changes in web-portal npm dependencies${NC}"
    update_npm_hash "web-portal"
fi

# Sanctions Service (Maven)
if file_changed "services/sanctions-service/pom\.xml"; then
    echo -e "${YELLOW}Detected changes in sanctions-service Maven dependencies${NC}"
    update_maven_hash "sanctions-service"
fi

# Smoke Tests (Ruby)
if file_changed "services/smoke-tests/(Gemfile|Gemfile\.lock)"; then
    echo -e "${YELLOW}Detected changes in smoke-tests Ruby dependencies${NC}"
    update_ruby_gemset "smoke-tests"
fi

# KYC Service (.NET)
if file_changed "services/kyc-service/.*\.csproj"; then
    echo -e "${YELLOW}Detected changes in kyc-service .NET dependencies${NC}"
    update_nuget_deps "kyc-service"
fi

# Fee Service (Python) - poetry2nix should handle this automatically
# But we can check if pyproject.toml or poetry.lock changed
if file_changed "services/fee-service/(pyproject\.toml|poetry\.lock)"; then
    echo -e "${YELLOW}Detected changes in fee-service Python dependencies${NC}"
    echo -e "${GREEN}poetry2nix should handle this automatically, but verifying build...${NC}"
    # Just verify it builds - poetry2nix generates hashes automatically
    if ! nix build ".#fee-service" 2>&1 | grep -q "error"; then
        echo -e "${GREEN}fee-service builds successfully${NC}"
    else
        echo -e "${YELLOW}fee-service may need manual attention${NC}"
    fi
fi

# Crypto Transfer (Rust) - cargoLock should handle this automatically
if file_changed "services/crypto-transfer/(Cargo\.toml|Cargo\.lock)"; then
    echo -e "${YELLOW}Detected changes in crypto-transfer Rust dependencies${NC}"
    echo -e "${GREEN}cargoLock should handle this automatically, but verifying build...${NC}"
    if ! nix build ".#crypto-transfer" 2>&1 | grep -q "error"; then
        echo -e "${GREEN}crypto-transfer builds successfully${NC}"
    else
        echo -e "${YELLOW}crypto-transfer may need manual attention${NC}"
    fi
fi

# Summary
echo ""
if [ "$HASHES_UPDATED" = true ]; then
    echo -e "${GREEN}✓ Some hashes were updated${NC}"
    echo -e "${YELLOW}Please review the changes and commit them.${NC}"
    
    # Write updated services to a file for the CI workflow to read
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        {
            echo "updated_services<<EOF"
            printf '%s\n' "${UPDATED_SERVICES[@]}"
            echo "EOF"
        } >> "$GITHUB_OUTPUT"
    fi
    
    # Also output for visibility
    echo ""
    echo "Updated services:"
    printf '  - %s\n' "${UPDATED_SERVICES[@]}"
    
    exit 0
else
    echo -e "${GREEN}✓ No hash updates needed - all hashes are correct${NC}"
    exit 0
fi

