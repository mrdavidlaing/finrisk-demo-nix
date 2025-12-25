# TransferX - Multi-Rail Funds Transfer Platform

A polyglot microservices demo platform showcasing Nix's ability to build reproducible, compliant systems across 6 different programming languages (Go, .NET, Python, Java, COBOL, Rust) plus a Next.js frontend.

## The Story

TransferX is a fictional fintech that handles both traditional bank transfers (via legacy SWIFT integration) and modern crypto transfers. Like any real financial platform, it's a polyglot system reflecting 20 years of technical decisions, acquisitions, and modernization efforts.

**Why this matters for compliance**: Every service has different dependency ecosystems, vulnerability profiles, and SBOM formats. The platform demonstrates how Nix provides unified, reproducible builds across all of them.

## Architecture

The platform consists of 7 services:

| Service | Language | Purpose | Port |
|---------|----------|---------|------|
| **web-portal** | Next.js/React | Customer transfer UI + Admin compliance dashboard | 3000 |
| **api-gateway** | Go | Central routing, authentication, rate limiting | 8080 |
| **kyc-service** | .NET 8 | Know Your Customer - identity verification | 8081 |
| **fee-service** | Python/FastAPI | Transfer fee calculation | 8082 |
| **sanctions-service** | Java/Spring Boot | OFAC/PEP sanctions screening | 8083 |
| **audit-service** | Perl | Transaction logging and audit trail | 8084 |
| **swift-gateway** | COBOL (GnuCOBOL) | SWIFT MT103 message generation | - |
| **crypto-transfer** | Rust/Axum | Cryptocurrency transfer processing | 8085 |

## Transfer Flow

1. Customer initiates transfer via web-portal
2. api-gateway routes request
3. kyc-service verifies sender identity
4. sanctions-service screens against OFAC/PEP lists
5. fee-service calculates transfer fee
6. Based on rail (SWIFT or CRYPTO):
   - **SWIFT**: swift-gateway generates MT103 batch file
   - **CRYPTO**: crypto-transfer executes blockchain transfer
7. audit-service logs transaction for compliance
8. Customer receives confirmation

## Quick Start

### Prerequisites

- Nix with flakes enabled
- Docker (for running services)

### Development Environment

```bash
# Enter development shell
nix develop

# Build all services
nix build .#all-services

# Build individual service
nix build .#api-gateway
nix build .#kyc-service
# ... etc
```

### Build Docker Images

```bash
# Build all Docker images
nix build .#all-images

# Load images into Docker
docker load < result

# Or build and load individual images
nix build .#api-gateway-image
docker load < result
```

### View Build Output

```bash
# Show what was built (even if cached)
nix run .#show-built

# Or use --print-out-paths to see store paths
nix build .#all-services --print-out-paths

# See build logs (even for cached builds)
nix build .#all-services --print-build-logs
```

### Run Services Locally

```bash
# Using docker-compose (after building images)
docker-compose up

# Or run services individually
nix run .#api-gateway
nix run .#kyc-service
# ... etc
```

### Access the Application

- **Web Portal**: http://localhost:3000
- **API Gateway**: http://localhost:8080
- **Admin Dashboard**: http://localhost:3000/admin

## Compliance Features

### SBOM Generation

Each service can generate Software Bill of Materials (SBOM) in CycloneDX format:

```bash
# Generate SBOMs (when implemented)
nix build .#all-sboms
```

### Vulnerability Scanning

Scan all Docker images for vulnerabilities:

```bash
# Scan all images
nix run .#scan-all

# Results saved to vulns-*.json files
```

### Admin Dashboard

The web portal includes an admin dashboard at `/admin` showing:

- **Service Health**: Status of all services
- **SBOMs**: Per-service dependency lists
- **Vulnerabilities**: CVE details with severity
- **Build Provenance**: Nix derivation hashes proving reproducibility

## Intentional Vulnerabilities

This demo includes intentional vulnerable dependencies to showcase compliance scanning:

- **api-gateway**: Old `golang.org/x/crypto` (CVE-2022-27191)
- **sanctions-service**: `log4j-core:2.14.1` (CVE-2021-44228 - Log4Shell!)
- **fee-service**: `urllib3<1.26.5` (CVE-2021-33503)
- **web-portal**: Older Next.js version with known CVEs

## Project Structure

```
transferx/
├── flake.nix                 # Main Nix flake
├── services/                 # Service source code
│   ├── web-portal/          # Next.js frontend
│   ├── api-gateway/         # Go service
│   ├── kyc-service/         # .NET service
│   ├── fee-service/         # Python service
│   ├── sanctions-service/   # Java service
│   ├── audit-service/       # Perl service
│   ├── swift-gateway/       # COBOL service
│   └── crypto-transfer/     # Rust service
├── nix/                     # Per-service Nix expressions
├── compliance/              # Generated SBOMs and vulnerability reports
├── .devcontainer/           # VSCode devcontainer config
└── docker-compose.yml       # Local development orchestration
```

## Nix Packaging

Each service uses native Nix builders:

- **Go**: `buildGoModule`
- **.NET**: `stdenv.mkDerivation` with `dotnet build`
- **Python**: `poetry2nix`
- **Java**: `stdenv.mkDerivation` with Maven
- **Perl**: `stdenv.mkDerivation` with Perl + CPAN modules
- **COBOL**: `stdenv.mkDerivation` with GnuCOBOL
- **Rust**: `rustPlatform.buildRustPackage`
- **Next.js**: `buildNpmPackage`

## Development

### Adding a New Service

1. Create service in `services/<service-name>/`
2. Create Nix expression in `nix/<service-name>.nix`
3. Add package to `flake.nix`
4. Add Docker image derivation
5. Update `docker-compose.yml`

### Testing

```bash
# Test individual service
nix build .#api-gateway
./result/bin/api-gateway

# Test full stack
docker-compose up
curl http://localhost:8080/api/health
```

## CI/CD & GitHub Actions

### Automated Workflows

The project includes comprehensive GitHub Actions workflows:

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **CI/CD** | Push to main, PRs, tags | Build services, generate SBOMs, publish images |
| **Nightly Scan** | Daily at 2 AM UTC | Vulnerability scanning of published images |
| **PR Check** | Pull requests | Build validation, SBOM diff, license check |

### Container Registry

Docker images are published to GitHub Container Registry (ghcr.io):

```bash
# Pull images
docker pull ghcr.io/<owner>/transferx/api-gateway:latest
docker pull ghcr.io/<owner>/transferx/kyc-service:latest
# ... etc
```

### SBOM Publishing

SBOMs are automatically:
- **Uploaded to GitHub Security**: Visible in the Dependency Graph
- **Attached to releases**: Download CycloneDX/SPDX SBOMs from releases
- **Attested to images**: SBOM attestations linked to container images

### Security Scanning

Vulnerability scan results are uploaded to GitHub Security:
- **Code Scanning Alerts**: View CVEs in the Security tab
- **Dependency Graph**: See all dependencies per service
- **SARIF Reports**: Both Grype and Trivy scanners

### Running Locally

```bash
# Replicate CI build
just build-all

# Generate SBOMs locally
just sboms

# Scan for vulnerabilities
just vulns
just vuln-summary
```

## Compliance & DORA/CRA Alignment

This demo showcases:

- **SBOM Generation**: Per-service CycloneDX & SPDX SBOMs
- **Vulnerability Scanning**: Grype + Trivy integration for all images
- **Build Provenance**: Nix derivation hashes + GitHub attestations
- **Dependency Submission**: Automatic upload to GitHub Security
- **Polyglot Support**: Unified build system across 7 languages (Go, .NET, Python, Java, Perl, COBOL, Rust)

Perfect for demonstrating compliance with:
- **DORA** (Digital Operational Resilience Act) - ICT risk management
- **CRA** (Cyber Resilience Act) - SBOM and vulnerability requirements
- **Executive Order 14028** - Software supply chain security

## License

MIT

## Contributing

This is a demo project. Feel free to fork and adapt for your own compliance demonstrations!
