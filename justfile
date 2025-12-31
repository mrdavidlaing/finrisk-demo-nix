# TransferX - Polyglot Microservices Platform
# Run `just --list` to see all available recipes

# Default recipe - show help
default:
    @just --list

# ============================================================================
# Build Targets
# ============================================================================

# Build all services (binaries only)
build:
    nix build .#all-services

# Build a specific service
build-service service:
    nix build .#{{service}}

# Build all Docker images
build-images:
    nix build .#all-images

# Build a specific Docker image
build-image service:
    nix build .#{{service}}-image

# Build everything (services + images)
build-all: build build-images

# ============================================================================
# Docker Targets
# ============================================================================

# Load all Docker images into Docker daemon
load-images: build-images
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Loading Docker images..."
    for img in result/*.tar.gz; do
        echo "  Loading $(basename $img)..."
        docker load < "$img"
    done
    echo "Done! Images loaded:"
    docker images | grep transferx

# Load a specific Docker image
load-image service: (build-image service)
    docker load < result

# Start all services with Docker Compose
up: load-images
    docker-compose up -d

# Start services in foreground (with logs)
up-logs: load-images
    docker-compose up

# Stop all services
down:
    docker-compose down

# Restart all services
restart: down up

# Show running services
ps:
    docker-compose ps

# Show logs for all services
logs:
    docker-compose logs -f

# Show logs for a specific service
logs-service service:
    docker-compose logs -f {{service}}

# ============================================================================
# Development Targets
# ============================================================================

# Enter Nix development shell
dev:
    nix develop

# Run the web portal in development mode
dev-web:
    cd services/web-portal && npm run dev

# Show what was built (paths and status)
show-built:
    nix run .#show-built

# Clean Nix build results
clean:
    rm -rf result result-*

# Clean Docker images
clean-docker:
    docker-compose down --rmi local || true
    docker images | grep transferx | awk '{print $3}' | xargs -r docker rmi -f || true

# Clean everything
clean-all: clean clean-docker

# ============================================================================
# Compliance & Security Targets
# ============================================================================

# Run full compliance scan (SBOMs + vulnerability scanning)
scan: sboms vulns

# Generate comprehensive CycloneDX SBOMs (base/runtime/app/container)
# Requires build to complete first so Syft can scan compiled outputs
sboms: build
    nix run .#generate-composed-sboms -- compliance/sboms

# Scan for vulnerabilities (requires SBOMs)
vulns:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p compliance/vulns
    SERVICES=$(nix eval --raw .#serviceRegistry.serviceList)
    for service in $SERVICES; do
        echo "Scanning $service for vulnerabilities..."
        grype "compliance/sboms/container-$service.cdx.json" -o json --file "compliance/vulns/$service.json"
    done

# Show vulnerability summary
vuln-summary:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Vulnerability Summary"
    echo "====================="
    for f in compliance/vulns/*.json; do
        service=$(basename "$f" .json)
        if [ -f "$f" ]; then
            critical=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' "$f" 2>/dev/null || echo "?")
            high=$(jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "$f" 2>/dev/null || echo "?")
            medium=$(jq '[.matches[] | select(.vulnerability.severity == "Medium")] | length' "$f" 2>/dev/null || echo "?")
            printf "%-20s Critical: %3s  High: %3s  Medium: %3s\n" "$service" "$critical" "$high" "$medium"
        fi
    done

# Upload SBOMs to Dependency Track
dt-upload-container-sboms:
    compliance/dependency-track/upload-sboms.sh

# ============================================================================
# SBOM Testing Targets
# ============================================================================

# Run all SBOM validation tests (fast tests only)
test-sboms:
    cd compliance/sbom-tests && bundle exec cucumber --profile fast

# Run SBOM tests and publish report to reports.cucumber.io
test-sboms-publish:
    cd compliance/sbom-tests && bundle exec cucumber --profile publish

# Run SBOM tests with specific profile (fast, slow, network, ci, strict, publish)
test-sboms-profile profile:
    cd compliance/sbom-tests && bundle exec cucumber --profile {{profile}}

# Run all SBOM tests except network tests (for CI)
test-sboms-ci:
    cd compliance/sbom-tests && bundle exec cucumber --profile ci

# Run only enforcement tests (tests that define requirements)
test-sboms-strict:
    cd compliance/sbom-tests && bundle exec cucumber --profile strict

# Run a specific SBOM feature file
test-sbom-feature feature:
    cd compliance/sbom-tests && bundle exec cucumber features/{{feature}}.feature

# Install SBOM test dependencies
setup-sbom-tests:
    cd compliance/sbom-tests && bundle install

# Generate SBOMs and test in one command
sboms-with-tests: sboms test-sboms

# ============================================================================
# Dependency Track Targets
# ============================================================================

# Start Dependency Track with initial configuration
dt-start:
    compliance/dependency-track/dt-manage.sh start

# Stop Dependency Track
dt-stop:
    compliance/dependency-track/dt-manage.sh stop

# Clear all Dependency Track projects (preserves config)
dt-reset:
    compliance/dependency-track/dt-manage.sh reset

# Show Dependency Track status
dt-status:
    compliance/dependency-track/dt-manage.sh status

# Trigger vulnerability analysis for all projects
dt-scan-vulnerabilities:
    compliance/dependency-track/dt-manage.sh scan

# Show Dependency Track logs
dt-logs:
    compliance/dependency-track/dt-manage.sh logs

# Follow Dependency Track logs
dt-logs-follow:
    compliance/dependency-track/dt-manage.sh logs -f

# Factory reset Dependency Track (removes all data)
dt-clean:
    compliance/dependency-track/dt-manage.sh clean

# ============================================================================
# Testing Targets
# ============================================================================

# Test all services are healthy
test-health:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Testing service health..."
    
    endpoints=(
        "http://localhost:8080/health:api-gateway"
        "http://localhost:8081/health:kyc-service"
        "http://localhost:8082/health:fee-service"
        "http://localhost:8083/actuator/health:sanctions-service"
        "http://localhost:8084/health:audit-service"
        "http://localhost:8085/health:crypto-transfer"
        "http://localhost:3000:web-portal"
    )
    
    for ep in "${endpoints[@]}"; do
        url="${ep%%:*}"
        # Handle URLs with port numbers
        service="${ep##*:}"
        if [[ "$service" =~ ^[0-9]+$ ]]; then
            # Last part was a port, extract service name differently
            service=$(echo "$ep" | rev | cut -d: -f1 | rev)
            url=$(echo "$ep" | rev | cut -d: -f2- | rev)
        fi
        printf "%-20s " "$service:"
        if curl -sf "$url" > /dev/null 2>&1; then
            echo "✓ healthy"
        else
            echo "✗ unhealthy"
        fi
    done

# Run a test transfer
test-transfer:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Submitting test transfer..."
    curl -X POST http://localhost:8080/api/transfer \
        -H "Content-Type: application/json" \
        -d '{
            "from_account": "US123456789",
            "to_account": "GB987654321", 
            "amount": 1000.00,
            "currency": "USD",
            "sender_name": "John Doe",
            "recipient_name": "Jane Smith"
        }' | jq .

# Run smoke tests against running services
smoke-test:
    curl -s http://localhost:8090/run-tests | jq .

# Run smoke tests and show summary only
smoke-test-summary:
    @curl -s http://localhost:8090/run-tests | jq '.summary'

# ============================================================================
# Individual Service Builds
# ============================================================================

# Build API Gateway (Go)
build-api-gateway:
    nix build .#api-gateway

# Build KYC Service (.NET)
build-kyc:
    nix build .#kyc-service

# Build Fee Service (Python)
build-fee:
    nix build .#fee-service

# Build Sanctions Service (Java)
build-sanctions:
    nix build .#sanctions-service

# Build SWIFT Gateway (COBOL)
build-swift:
    nix build .#swift-gateway

# Build Crypto Transfer (Rust)
build-crypto:
    nix build .#crypto-transfer

# Build Audit Service (Perl)
build-audit:
    nix build .#audit-service

# Build Web Portal (Next.js)
build-web:
    nix build .#web-portal

# ============================================================================
# Utility Targets
# ============================================================================

# Format Nix files
fmt:
    nixpkgs-fmt flake.nix release/*.nix

# Check flake
check:
    nix flake check

# Update flake inputs
update:
    nix flake update

# Show flake info
info:
    nix flake show

