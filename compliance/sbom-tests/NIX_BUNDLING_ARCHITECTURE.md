# Nix Bundling Architecture: Ecosystem Package Traceability Problem

**Document Version**: 1.0  
**Date**: December 31, 2025  
**Status**: Active Investigation Required  
**Related Commit**: `138280a` (feat: Add Nix traceability mapping for ecosystem packages in SBOMs)

## Executive Summary

The attempt to create Nix-to-Ecosystem package traceability in SBOMs revealed a fundamental architectural challenge: **Nix bundles ecosystem packages into runtime derivations rather than exposing them as individual Nix packages**. This means standard name-matching traceability strategies cannot map ecosystem packages (e.g., `pkg:pypi/anyio@3.7.1`) to Nix equivalents (e.g., `pkg:nix/python3.11-anyio@3.7.1`) because the individual Nix packages don't exist in the SBOM.

## Problem Statement

### Current Architecture

The SBOM generation pipeline combines two independent SBOM sources for each service:

1. **Nix SBOM** (via `sbomnix`): Captures Nix store dependencies
   - System libraries (glibc, openssl, zlib, etc.)
   - Language runtimes (python3-3.11.14, ruby3.3, etc.)
   - Build tools and utilities

2. **Ecosystem SBOM** (via `syft`): Captures language-specific packages
   - Python: PyPI packages from Nix build output
   - Ruby: Gem packages from Nix build output
   - Go: Cargo packages from Nix build output
   - Java: Maven/JAR components from Nix build output
   - .NET: NuGet packages from Nix build output
   - Node.js: npm packages from Nix build output
   - Rust: Cargo crates from Nix build output
   - Perl: CPAN modules from Nix build output

### The Fundamental Mismatch

**Expected Behavior** (what the traceability script assumed):
```
Nix packages exist individually:
  pkg:nix/python3.11-anyio@3.7.1
  pkg:nix/python3.11-fastapi@0.104.1
  pkg:nix/python3.11-requests@2.25.1
  ...
```

**Actual Behavior** (what Nix actually does):
```
Nix bundles all Python packages into a single derivation:
  pkg:nix/python3-3.11.14
    └─ Contains bundled: anyio, fastapi, requests, pydantic, ... (all 25 packages)
    └─ No individual Nix package entries

  pkg:pypi/anyio@3.7.1          ← Captured from build output
  pkg:pypi/fastapi@0.104.1      ← Captured from build output
  pkg:pypi/requests@2.25.1      ← Captured from build output
```

## Why Nix Bundles Packages

### 1. Reproducibility and Determinism

Nix's core principle is reproducibility. By bundling all dependencies into a single derivation with a specific output hash, Nix ensures:
- Exactly reproducible builds across machines
- No dependency version conflicts
- Deterministic closure calculation

### 2. Performance and Storage Efficiency

Individual package entries would require:
- Separate derivations for each version of each package
- More Nix store paths to manage
- Larger SBOMs with thousands of intermediate package references
- Slower closure calculations

### 3. Simplified Deployment Model

For containerized services, Nix bundles all dependencies into a single output directory:
```
/nix/store/...-python3.11-with-packages-0.1.0/
├── bin/
├── lib/
│   └── python3.11/
│       └── site-packages/
│           ├── anyio/
│           ├── fastapi/
│           ├── requests/
│           ...
└── share/
```

This is copied into containers as a single unit, not as individual packages.

## Detailed Analysis by Ecosystem

### Python (PyPI)

**Current Nix Setup**:
```nix
# In release/fee-service.nix
python3.withPackages (ps: with ps; [
  anyio
  fastapi
  requests
  pydantic
  # ... 25 packages total
])
```

**Resulting SBOM**:
```json
{
  "components": [
    {
      "name": "python3-3.11.14",
      "version": "",
      "purl": "pkg:nix/python3-3.11.14",
      "properties": [
        {"name": "nix:output_path", "value": "/nix/store/..."},
        {"name": "nix:drv_path", "value": "/nix/store/..."}
      ]
    },
    {
      "name": "anyio",
      "version": "3.7.1",
      "purl": "pkg:pypi/anyio@3.7.1"
    },
    {
      "name": "fastapi",
      "version": "0.104.1",
      "purl": "pkg:pypi/fastapi@0.104.1"
    }
    // ... 23 more PyPI packages
  ]
}
```

**Problem**: No way to trace `pkg:pypi/anyio@3.7.1` back to `pkg:nix/python3-3.11.14` via individual Nix packages.

**Current Limitation**: PyPI packages are disconnected from Nix build provenance.

### Ruby (Gems)

**Similar Architecture**:
```nix
# In release/smoke-tests.nix
ruby.withPackages (ps: with ps; [
  cucumber
  rspec
  faraday
  # ... 30+ gems
])
```

**SBOM Consequence**: 
- Gem packages visible in SBOM via Syft scanning
- No individual `pkg:nix/ruby3.3-cucumber` entries
- Cannot map back to Nix build that provided them

### Java (Maven/JAR)

**Different Approach - JAR Scanning**:
```nix
# In release/sanctions-service.nix
maven.buildMavenPackage {
  # ... build configuration
}
```

**SBOM Generation**:
- Syft scans the compiled JAR file in Nix store
- Discovers Java dependencies via bytecode analysis
- No corresponding Nix package entries

**Problem**: JAR contents are reverse-engineered; no direct link to Nix dependency specification.

### Go, Rust, Node.js, .NET

All follow similar patterns:
- **Go**: Binaries scanned for embedded dependencies
- **Rust**: Cargo audit entries extracted from compiled binaries
- **Node.js**: Package-lock.json scanned from build output
- **.NET**: DLL/assembly scanning (limited accuracy)

**Common Issue**: Ecosystem packages visible in SBOM, but no corresponding Nix package entries for traceability.

## Current SBOM Example: fee-service

### Raw Numbers
```
Total Components: 48
├── Nix Components: 23
│   ├── System Libraries: glibc, openssl, zlib, libffi, ncurses, readline, sqlite, ...
│   ├── Build Tools: gcc, bash, xz, bzip2, ...
│   └── Runtimes: python3-3.11.14
└── Ecosystem Components: 25 (PyPI packages)
    ├── anyio, certifi, chardet, click, colorama, fastapi, h11, httptools, idna,
    ├── iniconfig, packaging, pluggy, pydantic, pytest, python-dotenv, pyyaml,
    ├── requests, sniffio, starlette, typing-extensions, urllib3, uvicorn,
    └── uvloop, watchfiles, websockets
```

### Key Observation

**No bridges exist between tiers**:
```
Python Runtime (Nix):        pkg:nix/python3-3.11.14
                             │
                             ├─ (bundled, not traced)
                             │
Ecosystem Packages (PyPI):   pkg:pypi/anyio@3.7.1
                             pkg:pypi/fastapi@0.104.1
                             ... (24 more)
```

## Why the Traceability Script Failed

### Script Strategy

The `add-nix-traceability.py` script implemented a name-matching approach:

```python
def find_nix_equivalent(eco_pkg: EcosystemPackage, nix_components: List[dict]) -> Optional[dict]:
    """
    Find Nix component matching ecosystem package.
    
    Expected mapping:
    - pypi/anyio@3.7.1 → nix/python3.11-anyio@3.7.1
    - gem/cucumber@9.2.1 → nix/ruby3.3-cucumber@9.2.1
    """
    target_name = normalize_name(eco_pkg.name)
    target_version = eco_pkg.version
    
    for nix_comp in nix_components:
        base_name = extract_base_name(nix_comp.get("name"))
        if base_name and normalize_name(base_name) == target_name:
            if nix_comp.get("version") == target_version:
                return nix_comp  # ← NEVER RETURNS (Nix packages don't exist)
    
    return None  # ← ALWAYS RETURNS None
```

### Why It Failed

**Expected Nix Components** (in SBOM):
```
python3.11-anyio@3.7.1
python3.11-fastapi@0.104.1
ruby3.3-cucumber@9.2.1
```

**Actually Present** (in SBOM):
```
python3-3.11.14 (no -anyio, -fastapi suffixes)
ruby-3.3... (no individual gem entries)
```

**Result**: 0 matches found, 25 PyPI packages unmapped

```
[traceability] warning: 25 pypi packages have no Nix equivalent
[traceability] mapped 0 ecosystem packages to Nix
[traceability] 1 ecosystem types have no Nix equivalents
[traceability] removed 0 duplicate Nix components
```

## Impact on Vulnerability Analysis

### Current State

When a vulnerability is discovered in a PyPI package:
```
Vulnerability: CVE-2024-XXXXX in requests@2.25.1
├── Detected in: SBOM component pkg:pypi/requests@2.25.1
├── Nix Traceability: MISSING ❌
└── Nix Impact Analysis: IMPOSSIBLE 🚫
```

**Users cannot determine**:
- Which Nix build derivation included the vulnerable package
- Which services are affected at the Nix layer
- The exact Nix output paths that need rebuilding

### Desired State

```
Vulnerability: CVE-2024-XXXXX in requests@2.25.1
├── Detected in: SBOM component pkg:pypi/requests@2.25.1
├── Nix Traceability: pkg:nix/python3.11-requests@2.25.1
├── Bundled In: pkg:nix/python3-3.11.14
├── Service: fee-service
├── Nix Derivation: /nix/store/...-fee-service-0.1.0.drv
└── Requires Rebuild: ✅ yes
```

## Possible Solution Approaches

### Option 1: Extract Nix Dependency Graph from Derivations

**Concept**: Parse Nix derivation metadata to extract individual package dependencies.

**Pros**:
- Could provide accurate package-level traceability
- No changes to Nix packaging required
- Works with current architecture

**Cons**:
- Requires parsing complex Nix derivation outputs
- Metadata might be incomplete or non-standard
- Implementation complexity: HIGH

**Estimated Effort**: 2-3 weeks

---

### Option 2: Expose Individual Package Derivations in Nix

**Concept**: Modify Nix package definitions to create individual derivations for each package.

```nix
# Current approach (bundled)
python3.withPackages (ps: with ps; [anyio fastapi requests ...])

# Proposed approach (individual)
{
  python311anyio = python3.pkgs.anyio;
  python311fastapi = python3.pkgs.fastapi;
  python311requests = python3.pkgs.requests;
  ...
}
```

**Pros**:
- Native Nix solution
- Individual packages exposed in SBOM
- Simpler traceability logic

**Cons**:
- Requires significant changes to all service definitions
- Increases Nix store footprint
- Changes deployment model (more complexity)
- May hurt reproducibility if not careful

**Estimated Effort**: 3-4 weeks

---

### Option 3: Bidirectional Mapping via Source Analysis

**Concept**: Analyze source manifests (pyproject.toml, Gemfile, etc.) to map ecosystem packages back to Nix.

```python
# In add-nix-traceability.py
for service in SERVICES:
    source_packages = parse_source_manifest(f"services/{service}")
    # source_packages = {anyio: 3.7.1, fastapi: 0.104.1, ...}
    
    for eco_pkg in sbom.ecosystem_packages:
        if eco_pkg in source_packages:
            # Create synthetic Nix entry or link via externalReferences
            add_traceability(eco_pkg, service, source_packages[eco_pkg])
```

**Pros**:
- Works with current Nix architecture
- No changes to deployment
- Simpler implementation than Options 1-2

**Cons**:
- Source manifest parsing might miss transitive deps
- Not as authoritative as actual Nix derivations
- Maintenance burden (keep mapping logic in sync)

**Estimated Effort**: 1-2 weeks

---

### Option 4: Link via Container Build Context

**Concept**: For container SBOMs, capture the Nix environment variables that specify package versions.

```json
{
  "components": [{
    "purl": "pkg:pypi/anyio@3.7.1",
    "externalReferences": [{
      "type": "build-system",
      "url": "nix:env:NIX_PYTHON_PACKAGES_ANYIO=3.7.1",
      "comment": "Nix package environment reference"
    }]
  }]
}
```

**Pros**:
- Lightweight, metadata-only approach
- Non-intrusive (no changes to Nix or SBOMs structure)
- Fast to implement

**Cons**:
- Only works if environment variables are captured
- Less precise than true derivation traceability
- Might not work for all build systems

**Estimated Effort**: 1 week

---

### Option 5: Hybrid Approach (Recommended)

**Concept**: Combine multiple strategies based on ecosystem and availability:

1. **For Python/Ruby** (via source manifests):
   - Parse `pyproject.toml`, `Gemfile.lock`, `poetry.lock`
   - Create mapping entries via externalReferences
   - Fallback to name-matching if manifest unavailable

2. **For Java** (via JAR analysis):
   - Enhanced JAR scanning to capture Maven coordinates
   - Link via pom.xml in source

3. **For Go/Rust** (via lock files):
   - Parse `go.sum`, `Cargo.lock` from source
   - Create deterministic mappings

4. **Metadata fallback**:
   - Store mapping hints in SBOM properties
   - Document traceability confidence levels

**Pros**:
- Pragmatic, works with current architecture
- Gradually improvable (per-ecosystem)
- Extensible for future ecosystems

**Cons**:
- Implementation complexity: MEDIUM
- Requires per-ecosystem handling
- Not 100% authoritative

**Estimated Effort**: 3-4 weeks (full implementation)

---

## Technical Recommendations

### Short Term (Immediate)

1. **Document the Problem** ✅ (this document)
2. **Track as Known Limitation** in README
3. **Disable Traceability Mapping** in favor of alternative approaches
4. **Focus on other SBOM Quality Improvements**

### Medium Term (Next Sprint)

1. **Evaluate Option 5** (Hybrid approach)
2. **Implement Python/Ruby Manifest Parsing**
3. **Add externalReferences** for source-based traceability
4. **Create Test Fixtures** for validation

### Long Term (Architectural)

1. **Design Traceability Policy** for the organization
2. **Implement Selected Solution**
3. **Integrate with Vulnerability Scanner**
4. **Create Runbooks** for incident response

## Related Files and References

### Current Implementation
- `lib/sbom/add-nix-traceability.py` - Current (non-functional) traceability script
- `compliance/sbom-tests/features/10_nix_traceability.feature` - Test cases
- `flake.nix` - SBOM generation pipeline

### Service Definitions
- `release/fee-service.nix` - Example: Python service
- `release/smoke-tests.nix` - Example: Ruby service
- `release/sanctions-service.nix` - Example: Java service

### Generated SBOMs
- `compliance/sboms/app-*.cdx.json` - Individual service SBOMs
- `compliance/sboms/container-*.cdx.json` - Container composition SBOMs

## Questions for Future Investigation

1. **Nix Metadata**: Does sbomnix capture package-level dependency information in the SBOM?
   - If yes: Can we extract it?
   - If no: Can we request this feature from sbomnix maintainers?

2. **Derivation Analysis**: Can we parse `.drv` files to extract package dependencies?
   - What information is available in `/nix/store/*.drv` files?
   - Can we reliably extract package versions from them?

3. **Container Environment**: Are environment variables set during container build that capture package info?
   - Can we capture these in container SBOMs?
   - Do they persist into running containers?

4. **Source Analysis**: How reliable is manifest-based approach for different ecosystems?
   - Which ecosystems have deterministic, parseable manifests?
   - What about transitive vs. direct dependencies?

5. **Performance**: What's the performance impact of different solutions?
   - SBOM size increase?
   - Generation time impact?
   - Query/lookup time for traceability?

## Conclusion

The Nix Bundling Architecture fundamentally differs from traditional package-manager approaches where each package is individually installed. This architectural difference prevents straightforward name-matching traceability between ecosystem packages and Nix derivations.

**This is not a bug—it's a design choice** that enables Nix's reproducibility and deployment model.

However, **the lack of traceability is a real operational challenge** when managing vulnerabilities across multiple ecosystems.

**Recommended Path Forward**: Implement Option 5 (Hybrid approach) starting with source manifest analysis, which provides 80% of the value with 20% of the implementation complexity of full solutions.

---

**Next Steps**: 
1. Review this analysis with the team
2. Evaluate proposed solutions
3. Schedule separate agent session for implementation
4. Update this document with decision rationale
