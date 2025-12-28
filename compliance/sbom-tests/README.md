# SBOM BDD Test Suite

Comprehensive BDD test suite for validating SBOM quality requirements using Ruby/Cucumber.

## Purpose

- **Validate SBOM Requirements**: Deduplication, provenance, CVE matching
- **Living Documentation**: Gherkin scenarios communicate SBOM architecture
- **Quality Gates**: Fail builds on SBOM quality issues
- **Test-Driven Refactoring**: Enable confident SBOM generation improvements

## Quick Start

```bash
# Install dependencies
just setup-sbom-tests

# Run fast tests (< 30s)
just test-sboms

# Run tests and publish report to reports.cucumber.io
just test-sboms-publish

# Run all tests except network tests (for CI)
just test-sboms-ci

# Run specific profile
just test-sboms-profile strict  # Only enforced requirements
just test-sboms-profile network  # Include NVD API tests
```

## Test Tags

### Performance
- `@fast` - Quick tests (< 1s each), no network
- `@slow` - Heavy I/O or computation
- `@network` - Requires internet (NVD API lookups)

### State
- `@current_state` - Documents what currently exists (passes now)
- `@enforce_fix` - Defines what SHOULD be true (may fail until fixed)
- `@known_issue` - Tracked limitations
- `@wontfix` - Documented limitations not being addressed

## Test Features

### 01. SBOM Structure (`01_sbom_structure.feature`)
Validates CycloneDX 1.5 specification compliance:
- All required SBOM files exist (base, runtime, app, container)
- Valid bomFormat, specVersion, serialNumber
- Metadata contains correct component references
- External references link to layer SBOMs

### 02. Deduplication (`02_deduplication.feature`)
Ensures identical components have identical PURLs across containers:
- glibc, bash, coreutils have same PURL in all containers
- Enables accurate vulnerability tracking in Dependency Track
- **Critical**: Same source package must not appear as duplicates

### 03. Provenance (`03_provenance.feature`)
Traces components back to their layers:
- Container SBOMs reference base/runtime/app layer SBOMs
- Compositions section links to all three layers
- **Future**: Components tagged with layer property (base/runtime/app)
- Enables understanding of software supply chain

### 04. CPE Validation (`04_cpe_validation.feature`)
Validates CPE identifiers for CVE database matching:
- CPEs follow CPE 2.3 format specification
- Correct vendor mappings (glibc → gnu, not glibc)
- No Nix package suffixes in versions (2.40, not 2.40-66)
- **Network tests**: Validate CPEs exist in NVD database

### 05. PURL Validation (`05_purl_validation.feature`)
Validates Package URL format and correctness:
- All library/application components have PURLs
- PURLs match ecosystem patterns (pkg:nix/, pkg:npm/, etc.)
- Components have correct PURL types for their ecosystems
- Well-formed name and version components

### 06. Composition (`06_composition.feature`)
Validates CycloneDX compositions metadata:
- All container SBOMs have compositions section
- Compositions declare "complete" aggregation
- Exactly 3 assemblies referenced (base + runtime + app)
- Assembly refs have valid BOM-ref format
- **Enforcement**: Referenced SBOM files actually exist

### 07. Quality Gates (`07_quality_gates.feature`)
Ensures SBOMs contain only legitimate components:
- **No GitHub workflow files** in SBOMs
- No CI/CD configuration files
- All components have valid types (library/application/framework)
- Required fields present (name, type)
- Layer SBOMs have appropriate component counts
- Container SBOMs aggregate all layer components

## Running Tests

### Local Development
```bash
cd compliance/sbom-tests

# Run fast tests
bundle exec cucumber --profile fast

# Run specific feature
bundle exec cucumber features/02_deduplication.feature

# See what needs fixing
bundle exec cucumber --tags @enforce_fix

# Run current state tests
bundle exec cucumber --tags @current_state
```

### CI Integration
Tests run automatically in CI after SBOM generation. See `.github/workflows/ci.yml`.

**Note**: Tests use Ruby 3.3 (via Nix devShell).

### Publishing Reports
Share test results with your team at [reports.cucumber.io](https://reports.cucumber.io):

```bash
# Publish report (generates shareable URL)
just test-sboms-publish
```

The report will be published and you'll receive a URL to share. Reports are **public by default** on the free tier.

## Hybrid Approach

Each requirement has TWO scenarios:
- **Current State** (`@current_state`) - Documents current behavior
- **Enforcement** (`@enforce_fix`) - Defines target state

As fixes are implemented, enforcement tests pass and current state tests fail (expected).

## Directory Structure

```
compliance/sbom-tests/
├── features/
│   ├── 01_sbom_structure.feature    # File existence, schema
│   ├── 02_deduplication.feature     # Cross-container consistency
│   ├── 03_provenance.feature        # Layer tracing
│   ├── 04_cpe_validation.feature    # CPE correctness
│   ├── 05_purl_validation.feature   # PURL format
│   ├── 06_composition.feature       # Compositions metadata
│   ├── 07_quality_gates.feature     # Quality checks
│   ├── support/
│   │   ├── env.rb                   # Test environment
│   │   └── helpers/                 # Validation logic
│   │       ├── sbom_loader.rb       # SBOM loading/querying
│   │       ├── purl_validator.rb    # PURL parsing/validation
│   │       ├── cpe_validator.rb     # CPE parsing/validation
│   │       └── composition_analyzer.rb  # Compositions analysis
│   └── step_definitions/            # Cucumber steps
│       ├── sbom_structure_steps.rb
│       ├── deduplication_steps.rb
│       ├── provenance_steps.rb
│       ├── cpe_validation_steps.rb
│       ├── purl_validation_steps.rb
│       ├── composition_steps.rb
│       └── quality_gates_steps.rb
├── fixtures/                         # Expected values and mappings
│   ├── nvd_cpe_mappings.yml         # CPE vendor corrections
│   ├── expected_components.yml      # Layer component expectations
│   └── service_runtime_map.yml      # Service-to-runtime mapping
├── Gemfile                          # Ruby dependencies
├── cucumber.yml                     # Test profiles
└── tmp/                             # Test results (gitignored)
```

## Fixtures

### `nvd_cpe_mappings.yml`
Maps package names to correct CPE vendors for NVD compatibility:
```yaml
vendor_mappings:
  glibc: gnu      # Not glibc:glibc, but gnu:glibc
  bash: gnu
  openssl: openssl
  python: python
```

Also defines version normalization rules (remove Nix suffixes).

### `expected_components.yml`
Defines expected components in each layer:
- Base layer: Core system libraries (glibc, bash, openssl)
- Runtime layers: Language-specific components (nodejs, python, go, dotnet)
- Forbidden components: What should NOT appear in each layer
- Minimum component counts for validation

### `service_runtime_map.yml`
Maps services to their expected runtimes and SBOMs:
```yaml
services:
  web-portal:
    runtime: nodejs
    runtime_sbom: runtime-nodejs.cdx.json
    app_sbom: app-web-portal.cdx.json
```

Used to validate service-to-runtime relationships.

## Known Issues and Enforcement

The test suite documents current SBOM issues and enforces fixes:

### ✅ Working Correctly (Passing Tests)
- **Deduplication**: glibc, bash, coreutils have identical PURLs across containers
- **SBOM Structure**: All files exist with valid CycloneDX 1.5 format
- **Compositions**: Container SBOMs reference all three layer SBOMs
- **PURL Format**: Components have well-formed PURLs

### ⚠️ Issues Documented (Will Fix)
These `@enforce_fix` tests will fail until the SBOM generation is corrected:

1. **CPE Vendor Mapping** (`04_cpe_validation.feature`)
   - Current: `cpe:2.3:a:glibc:glibc:2.40-66`
   - Required: `cpe:2.3:a:gnu:glibc:2.40`
   - Impact: CVE matching fails in vulnerability databases

2. **CPE Version Suffixes** (`04_cpe_validation.feature`)
   - Current: Versions include Nix package suffixes (2.40-66)
   - Required: Clean semantic versions (2.40)
   - Impact: NVD lookups fail or return wrong results

3. **GitHub Workflow Files in SBOMs** (`07_quality_gates.feature`)
   - Current: 13 `.github/workflows/` entries in container SBOMs
   - Required: Zero non-package components
   - Impact: Noise in vulnerability reports, inflated component counts

4. **Component Layer Tags** (`03_provenance.feature`)
   - Current: Components lack layer property tags
   - Required: Each component tagged with origin layer (base/runtime/app)
   - Impact: Cannot trace which layer introduced a vulnerable component

### 🔄 Hybrid Testing Approach
Each issue has two test scenarios:
- `@current_state` - Documents current behavior (passes now)
- `@enforce_fix` - Defines required behavior (fails until fixed)

Run both to see current state vs. target state:
```bash
just test-sboms-profile dev     # Skip enforcement tests
just test-sboms-profile strict  # Only enforcement tests
```

## Adding New Tests

1. Create feature file in `features/`
2. Use Gherkin syntax for readability
3. Tag appropriately (`@fast`, `@enforce_fix`, etc.)
4. Implement step definitions
5. Run tests to verify

## Troubleshooting

### Tests fail with "SBOM directory not found"
```bash
# Generate SBOMs first
just sboms
```

### Tests fail with bundle errors
```bash
# Reinstall dependencies
rm -rf .bundle Gemfile.lock
bundle install
```

### Network tests timeout
```bash
# Skip network tests
just test-sboms-ci
```

## See Also

- **Plan**: `/home/mrdavidlaing/.claude/plans/snoopy-strolling-waterfall.md`
- **SBOM Generation**: `just sboms`
- **Smoke Tests**: `services/smoke-tests/` (similar pattern)
