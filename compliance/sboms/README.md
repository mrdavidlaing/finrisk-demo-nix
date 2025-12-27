# SBOM Structure and Relationships

This directory contains Software Bill of Materials (SBOM) files in CycloneDX format for the finrisk-demo-nix project. The SBOMs are organized in a hierarchical structure that reflects how container images are built from base components, runtime environments, and application code.

## SBOM Hierarchy

The SBOMs follow a layered architecture:

```
┌─────────────────────────────────────┐
│   Container SBOMs (Aggregate)       │
│   container-{service}.cdx.json      │
│   - References base + runtime + app  │
│   - Complete container image BOM    │
└──────────────┬──────────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
│ Base SBOM   │  │ Runtime     │  │ App SBOMs   │
│ base.cdx    │  │ SBOMs       │  │ app-*.cdx   │
│             │  │ runtime-*.cdx│  │             │
│ Common      │  │ Language    │  │ Service-    │
│ system      │  │ specific    │  │ specific    │
│ components  │  │ runtimes    │  │ deps        │
└─────────────┘  └─────────────┘  └─────────────┘
```

## SBOM Types

### 1. Base SBOM (`base.cdx.json`)
**Purpose**: Contains common base system components shared across all containers.

**Contents**:
- Core system libraries (glibc, bash, coreutils)
- Base utilities (tzdata, nss-cacert)
- System-level dependencies

**Used by**: All container SBOMs

### 2. Runtime SBOMs (`runtime-*.cdx.json`)
**Purpose**: Language-specific runtime environments and their dependencies.

**Available Runtimes**:
- `runtime-node.cdx.json` - Node.js runtime (Node.js 20.19.6, libuv, OpenSSL, etc.)
- `runtime-java.cdx.json` - Java runtime (JVM and Java libraries)
- `runtime-python.cdx.json` - Python runtime (Python interpreter and standard libraries)
- `runtime-dotnet.cdx.json` - .NET runtime (ASP.NET Core runtime)
- `runtime-ruby.cdx.json` - Ruby runtime
- `runtime-perl.cdx.json` - Perl runtime
- `runtime-native.cdx.json` - Native/compiled binaries (no language runtime needed)

**Used by**: Container SBOMs based on the service's implementation language

### 3. App SBOMs (`app-*.cdx.json`)
**Purpose**: Application-specific dependencies for each service.

**Available Apps**:
- `app-api-gateway.cdx.json`
- `app-audit-service.cdx.json`
- `app-crypto-transfer.cdx.json`
- `app-fee-service.cdx.json`
- `app-kyc-service.cdx.json`
- `app-sanctions-service.cdx.json`
- `app-smoke-tests.cdx.json`
- `app-swift-gateway.cdx.json`
- `app-web-portal.cdx.json`

**Contents**: Service-specific dependencies, libraries, and components unique to each application.

**Note**: For services with language-specific package managers:
- **Node.js services** (web-portal): Includes npm dependencies extracted from `package.json` and merged with Nix dependencies
- **Java/Maven services** (sanctions-service): Includes Maven dependencies extracted from the JAR file and merged with Nix dependencies
- **.NET services** (kyc-service): Includes NuGet dependencies extracted from .NET assemblies and merged with Nix dependencies
- **Rust services** (crypto-transfer): Includes Cargo dependencies extracted from `Cargo.toml`/`Cargo.lock` and merged with Nix dependencies
- **Go services** (api-gateway): Includes Go module dependencies extracted from `go.mod`/`go.sum` and merged with Nix dependencies
- **Perl services** (audit-service): Includes Perl/CPAN dependencies extracted from `Makefile.PL` and merged with Nix dependencies
- **Python services** (fee-service): Includes Python/PyPI dependencies extracted from `pyproject.toml`/`poetry.lock` and merged with Nix dependencies
- **Ruby services** (smoke-tests): Includes Ruby/RubyGems dependencies extracted from `Gemfile`/`Gemfile.lock` and merged with Nix dependencies
- **Native services** (swift-gateway): Uses system libraries managed by Nix; dependencies are captured as Nix packages

### 4. Container SBOMs (`container-*.cdx.json`)
**Purpose**: Complete SBOM for each container image, aggregating base + runtime + app.

**Structure**: Each container SBOM:
1. References three external SBOMs via `externalReferences`:
   - `base.cdx.json`
   - `runtime-{language}.cdx.json` (language-specific)
   - `app-{service}.cdx.json` (service-specific)

2. Contains all components from the referenced SBOMs (flattened)

3. Defines a `compositions` section showing how components are assembled

## Service-to-Runtime Mapping

| Service | Container SBOM | Runtime Used | App SBOM |
|---------|---------------|--------------|----------|
| api-gateway | `container-api-gateway.cdx.json` | `runtime-native.cdx.json` | `app-api-gateway.cdx.json` |
| audit-service | `container-audit-service.cdx.json` | `runtime-perl.cdx.json` | `app-audit-service.cdx.json` |
| crypto-transfer | `container-crypto-transfer.cdx.json` | `runtime-native.cdx.json` | `app-crypto-transfer.cdx.json` |
| fee-service | `container-fee-service.cdx.json` | `runtime-python.cdx.json` | `app-fee-service.cdx.json` |
| kyc-service | `container-kyc-service.cdx.json` | `runtime-dotnet.cdx.json` | `app-kyc-service.cdx.json` |
| sanctions-service | `container-sanctions-service.cdx.json` | `runtime-java.cdx.json` | `app-sanctions-service.cdx.json` |
| smoke-tests | `container-smoke-tests.cdx.json` | `runtime-ruby.cdx.json` | `app-smoke-tests.cdx.json` |
| swift-gateway | `container-swift-gateway.cdx.json` | `runtime-native.cdx.json` | `app-swift-gateway.cdx.json` |
| web-portal | `container-web-portal.cdx.json` | `runtime-node.cdx.json` | `app-web-portal.cdx.json` |

## Example: Container SBOM Structure

Looking at `container-api-gateway.cdx.json`:

```json
{
  "metadata": {
    "component": {
      "type": "container",
      "name": "transferx/api-gateway",
      "externalReferences": [
        { "type": "bom", "url": "base.cdx.json" },
        { "type": "bom", "url": "runtime-native.cdx.json" },
        { "type": "bom", "url": "app-api-gateway.cdx.json" }
      ]
    }
  },
  "components": [
    // All components from base, runtime-native, and app-api-gateway
  ],
  "dependencies": [
    // Dependency graph combining all three layers
  ],
  "compositions": [
    {
      "aggregate": "complete",
      "assemblies": [
        "transferx-base-set",
        "transferx-runtime-native",
        "api-gateway"
      ]
    }
  ]
}
```

## Benefits of This Structure

1. **Reusability**: Base and runtime SBOMs are shared across multiple services
2. **Modularity**: Each layer can be updated independently
3. **Traceability**: Clear separation between base system, runtime, and application dependencies
4. **Compliance**: Easy to identify which components are shared vs. service-specific
5. **Efficiency**: Avoids duplication while maintaining complete visibility

## Usage

- **Container SBOMs**: Use for complete container image compliance and vulnerability scanning
- **App SBOMs**: Use to understand service-specific dependencies
- **Runtime SBOMs**: Use to understand language runtime dependencies
- **Base SBOM**: Use to understand shared system-level components

## Tools

These SBOMs were generated using:
- **Tool**: `sbomnix` (version 1.7.4)
- **Vendor**: TII
- **Format**: CycloneDX 1.4/1.5

