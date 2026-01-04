# Nix SBOM Traceability: Goals, Limitations, and Approaches

## Project Overview

The TransferX project uses Nix to build polyglot microservices. We generate comprehensive Software Bill of Materials (SBOMs) in CycloneDX format to:
- Track dependencies across all services
- Enable vulnerability scanning
- Provide complete build provenance

## Goal: Nix Traceability

### What We Want to Achieve

For every ecosystem package (PyPI, Gem, npm, Maven, etc.) that Syft discovers in compiled artifacts, we want to add **Nix build provenance**:

```json
{
  "bom-ref": "pkg:pypi/pytest@7.4.4",
  "type": "library",
  "name": "pytest",
  "version": "7.4.4",
  "purl": "pkg:pypi/pytest@7.4.4",
  "properties": [
    {
      "name": "nix:purl",
      "value": "pkg:nix/python3.11-pytest@7.4.4"
    },
    {
      "name": "nix:drv",
      "value": "/nix/store/...-pytest-7.4.4.drv"
    },
    {
      "name": "nix:output",
      "value": "/nix/store/gqky1yvwc72kmbn1ymjyaanz842w0lgv-python3.11-pytest-7.4.4"
    },
    {
      "name": "sbom:scope",
      "value": "dev-only"  // or "runtime"
    }
  ],
  "externalReferences": [
    {
      "type": "build-system",
      "url": "nix:store:/nix/store/gqky1yvwc72kmbn1ymjyaanz842w0lgv-python3.11-pytest-7.4.4",
      "comment": "Nix derivation output"
    }
  ],
  "scope": "excluded"  // or "required"
}
```

### Why This Matters

1. **Vulnerability Traceability**: When Grype finds a CVE in `pytest@7.4.4`, we can trace it back to the exact Nix store path that was built
2. **Build Provenance**: Each package can be traced to its derivation `.drv` file, showing the exact build recipe
3. **Scope Awareness**: Distinguish between runtime dependencies (deployed) and dev dependencies (testing only)
4. **Reproducibility**: Knowing exactly which Nix outputs were used enables perfect reproducibility

### The SBOM Generation Workflow

```
1. Generate Nix SBOM (sbomnix)
   ├─ Scans Nix build outputs
   └─ Produces: pkg:nix/python3.11-pytest@7.4.4

2. Generate Ecosystem SBOM (syft)
   ├─ Scans compiled artifacts
   └─ Produces: pkg:pypi/pytest@7.4.4

3. Merge SBOMs
   └─ Combine Nix + ecosystem components

4. Add Nix Traceability (add-nix-traceability.py)
   ├─ Match ecosystem packages to Nix equivalents
   ├─ Add nix:purl, nix:drv, nix:output properties
   ├─ Add sbom:scope (runtime vs dev-only)
   └─ Add externalReference to Nix store output

5. Compose Container SBOM
   └─ base + runtime + app SBOMs
```

## The Core Problem

### Nix Derivation Coercion

**The fundamental limitation**: When Nix serializes derivation objects to JSON, they are **coerced to their store paths**, losing all metadata.

#### Example: Fee Service Python Packages

In Nix evaluation (in `fee-service.nix`):

```nix
# This list contains Python package derivation objects
runtimePackages = app.passthru.requiredPythonModules or [];
```

Each element in `runtimePackages` has these attributes:
```nix
{
  pname = "pytest";        # ✅ Available during evaluation
  version = "7.4.4";        # ✅ Available during evaluation
  outPath = "/nix/store/..."; # ✅ Available during evaluation
  drvPath = "/nix/store/...";  # ✅ Available during evaluation
}
```

**But when we try to serialize to passthru**:

```nix
passthru = {
  sbomDependencies = {
    runtime = builtins.map (pkg: {
      name = pkg.pname;      # ❌ Coerced during serialization
      version = pkg.version;  # ❌ Coerced during serialization
      outPath = pkg.outPath; # ✅ Works (already a path)
      drvPath = pkg.drvPath; # ❌ Coerced during serialization
    }) runtimePackages;
  };
}
```

**Result when serialized**:

```json
{
  "runtime": [
    "/nix/store/gqky1yvwc72kmbn1ymjyaanz842w0lgv-python3.11-pytest-7.4.4",
    "/nix/store/9wbghn29c7kb0d5kh7gwf3np566nbrwk-python3.11-fastapi-0.104.1",
    ...
  ]
}
```

**All metadata lost!** We only have store paths, no `pname`, `version`, or `drvPath`.

### Why Nix Does This

Nix enforces **pure evaluation** with these guarantees:

1. **Deterministic**: Same inputs → same outputs (no external state)
2. **Hermetic**: No filesystem/network access during evaluation
3. **Reproducible**: Evaluation order doesn't matter
4. **Cacheable**: Results can be cached indefinitely

**Derivation objects violate these guarantees** when serialized:
- They reference `.drv` files (imperative build artifacts)
- They contain build-time state not available during pure evaluation
- The only portable, safe representation is the **store path itself**

Thus, Nix automatically coerces:
```nix
derivation object → store path (string)
```

## Impact on Implementation

### Direct Impact: Test Failures

The SBOM tests (`compliance/sbom-tests/features/10_nix_traceability.feature`) fail because:

| Test | What It Checks | Current Reality |
|-------|----------------|-----------------|
| "Each package should have nix:purl property" | All PyPI/Gem packages linked to Nix packages | ❌ Can't link - no metadata |
| "Each package should have nix:output property" | Store path to Nix output | ❌ Can't provide - no metadata |
| "Each package should have nix:drv property" | Link to derivation file | ❌ Can't provide - no metadata |
| "Each package should have sbom:scope property" | Runtime vs dev-only distinction | ❌ Can't classify - no scope info |
| "External references to Nix store" | Build provenance links | ❌ Can't create - no drv info |

**Result**: 9 scenarios fail, 136 pass
- 25 PyPI packages missing traceability
- 43 Gem packages missing traceability
- 0 packages with scope classification
- 0 packages with external references

### Secondary Impact: Operational

1. **Vulnerability Management**
   - Vulnerability scanners find CVE in ecosystem packages
   - Can't trace to exact Nix build
   - Can't verify if vulnerable package is actually deployed (runtime vs dev)

2. **Build Reproducibility**
   - SBOM shows package versions but not Nix derivations
   - Can't guarantee reproducibility between builds
   - Can't debug build differences

3. **Compliance Reporting**
   - Missing build provenance attributes
   - Can't meet traceability requirements
   - Incomplete supply chain visibility

## Approaches Tried

### Approach 1: Direct passthru Serialization (❌ Failed)

**Attempt**: Expose complete metadata in passthru

```nix
# release/fee-service.nix
extractPackageInfo = pkg: {
  name = builtins.toString (pkg.pname or pkg.name or "unknown");
  version = builtins.toString (pkg.version or "unknown");
  outPath = builtins.toString pkg.outPath;
  drvPath = builtins.toString pkg.drvPath;
};

passthru = {
  sbomDependencies = {
    runtime = builtins.map extractPackageInfo runtimePackages;
  };
}
```

**What we expected**:
```json
{
  "runtime": [
    {
      "name": "python3.11-pytest",
      "version": "7.4.4",
      "outPath": "/nix/store/...",
      "drvPath": "/nix/store/...pytest-7.4.4.drv"
    }
  ]
}
```

**What happened**:
```bash
$ nix eval --json '.#fee-service.passthru.sbomDependencies.runtime'
# ERROR: string "..." is not allowed to refer to a store path
```

**Why it failed**: During JSON serialization, each `pkg` object got coerced to its `outPath` string before `extractPackageInfo` could read `pkg.pname`, `pkg.version`, etc. The result was an array of strings (store paths), not objects.

### Approach 2: Use passthru Paths + Name Parsing (❌ Partial)

**Attempt**: Store just paths in passthru, parse metadata from path names

```nix
# release/fee-service.nix
passthru = {
  sbomRuntimePaths = builtins.map (p: p.outPath) runtimePackages;
  sbomDevOnlyPaths = builtins.map (p: p.outPath) devPackages;
}
```

Then in `flake.nix`:
```bash
extract_sbom_deps() {
  # Get paths from Nix
  runtime_paths=$(nix eval --raw ".#$service.passthru.sbomRuntimePaths")

  # Parse metadata from store path names
  # Format: /nix/store/hash-name-version
  # Example: /nix/store/gqky1...-python3.11-pytest-7.4.4
  for path in $runtime_paths; do
    basename=$(basename "$path")
    clean_name="${basename#*-}"      # python3.11-pytest-7.4.4
    name="${clean_name%-*}"          # python3.11-pytest
    version="${clean_name##*-}"       # 7.4.4
  done
}
```

**What we expected**:
```json
{
  "name": "python3.11-pytest",
  "version": "7.4.4",
  "outPath": "/nix/store/..."
}
```

**What happened**: Could extract `name` and `version`, but **could not get `drvPath`**.

**Why it's incomplete**:
- Path parsing works for well-formed names
- But `drvPath` is not encoded in the output path
- No way to find the `.drv` file from just the output path
- Tests still fail (missing `nix:drv` property)

### Approach 3: Post-Build Derivation Queries (⚠️ Problematic)

**Attempt**: Query `.drv` files after builds to extract metadata

```bash
# In flake.nix
extract_sbom_deps() {
  # Build service first
  nix build ".#$service"

  # Find .drv files in references
  for out_path in $runtime_paths; do
    drv_path=$(nix-store -q --references "$out_path" | grep '\.drv$')

    # Query derivation metadata
    metadata=$(nix derivation show "$drv_path")

    # Extract name/version from .drv env
    name=$(echo "$metadata" | jq -r '.env.name // .env.pname')
    version=$(echo "$metadata" | jq -r '.env.version')
  done
}
```

**What this would provide**:
```json
{
  "name": "pytest",
  "version": "7.4.4",
  "outPath": "/nix/store/...",
  "drvPath": "/nix/store/...pytest-7.4.4.drv"  ✅ Now available!
}
```

**Why we haven't implemented this**: Breaks Nix design principles

#### Problems with Post-Build Queries

**1. Breaks Purity**
```bash
# Pure Nix evaluation (what we have):
nix eval '.#fee-service'
# Reads .nix files only
# No filesystem I/O
# Reproducible, cacheable

# Post-build queries (the workaround):
nix derivation show /nix/store/...pytest.drv
# Reads .drv files from disk
# Depends on build artifacts existing
# Imperative, not cacheable
```

**2. Circular Dependencies**
```bash
# Current desired workflow:
just sboms
  → nix eval .#fee-service (just metadata, no build)
  → Generate SBOMs using metadata
  → Complete

# With post-build queries:
just sboms
  → Need to read .drv files
     → But .drv files don't exist yet!
  → Must first build: nix build .#fee-service
     → But we're building it to generate SBOMs!
  → Chicken-and-egg problem
```

**3. Violates Declarativeness**
```nix
# Declarative (what we want):
{
  passthru = {
    sbomDependencies = { /* metadata from Nix eval */ };
  };
}

# Post-build (what we're forced to do):
passthru = {
  sbomDependencies = [];  # Empty during eval
};

# Then run shell command:
nix derivation show $(find .drv files)  # Imperative
```

**4. Breaks Hydra/CI**
```bash
# Pure evaluation (works everywhere):
nix eval .#serviceRegistry  # Returns JSON, no builds
# Can be cached, fast

# Post-build queries (require builds):
nix build .#fee-service          # Takes 5+ minutes
nix derivation show $(find .drv)  # Only works after build
# Can't introspect without building
```

**5. Not Cacheable**
```bash
# Pure eval:
$ nix eval .#fee-service.passthru
# Can cache result indefinitely
# Same result on every machine

# Post-build:
$ nix derivation show /nix/store/$(hash)-pytest.drv
# Depends on local store state
# Can't cache across machines
```

### Approach 4: Helper Script with Path Parsing (❌ Incomplete)

**Attempt**: Create Python script to parse store paths

```python
# lib/sbom/extract-nix-deps.py
def extract_metadata(paths_str):
    for path in paths:
        basename = path.split("/")[-1]
        clean_name = basename[33:]  # Remove hash
        name, version = clean_name.rsplit("-", 1)  # Split on last -
        return {"name": name, "version": version, "outPath": path}
```

**What we achieved**:
- ✅ Extract `name` from path
- ✅ Extract `version` from path
- ✅ Extract `outPath` (already have it)
- ❌ Still missing `drvPath`

**Why it's incomplete**: Same limitation as Approach 2 - drvPath not in path name.

## The Root Cause

### Ecosystem Package Builders Don't Expose Metadata

The real issue is in **poetry2nix** and **bundlerEnv**:

```nix
# What poetry2nix provides:
{
  passthru = {
    requiredPythonModules = [ /nix/store/...-pytest-7.4.4, ... ];
    # Derivation objects lost during passthru serialization
  };
}

# What we need:
{
  passthru = {
    requiredPythonModules = [
      {
        name = "pytest";
        version = "7.4.4";
        outPath = "/nix/store/...";
        drvPath = "/nix/store/...pytest-7.4.4.drv";
      },
      ...
    ];
  };
}
```

The issue is **upstream** - these package builders don't preserve metadata in a JSON-serializable way.

## Possible Solutions

### Solution 1: Modify Upstream Builders (⭐ Best)

Modify **poetry2nix** and **bundlerEnv** to expose serializable metadata:

```nix
# In poetry2nix output
{
  passthru = {
    requiredPythonModules = packages;
    sbomDependencies = [
      {
        name = "pytest";
        version = "7.4.4";
        outPath = "/nix/store/...";
        drvPath = "/nix/store/...pytest-7.4.4.drv";
      },
      ...
    ];  # Objects that serialize correctly
  };
}
```

**Pros**:
- ✅ Pure Nix evaluation
- ✅ No post-build queries
- ✅ Cacheable
- ✅ Declarative

**Cons**:
- ❌ Requires upstream contribution
- ❌ Complex implementation in builders

### Solution 2: Derivation Files in Store (✓ Works)

**Observation**: Every output has a `.drv` file in the store with same hash:

```
/nix/store/gqky1...-python3.11-pytest-7.4.4   (output)
/nix/store/5rch3...-python3.11-pytest-7.4.4.drv  (derivation)
```

The `.drv` file name shares the same hash prefix!

**Approach**: Reconstruct drv path from out path:

```bash
extract_drv_path() {
  local out_path="$1"
  # /nix/store/hash-name-version → hash
  local hash=$(basename "$out_path" | cut -d- -f1)
  # Derivation: /nix/store/hash-package-version.drv
  local out_dir=$(dirname "$out_path")
  find "$out_dir" -name "${hash}*.drv" -type f | head -1
}
```

**Pros**:
- ✅ Can find drv path without post-build queries
- ✅ Works if package is built
- ✅ No filesystem writes

**Cons**:
- ⚠️ Still requires package to be built
- ⚠️ May find multiple .drv files (hash collisions)
- ⚠️ Imperative file search

### Solution 3: Store Metadata Separately (✓ Cleanest)

Create JSON file with metadata during package derivation:

```nix
# release/fee-service.nix
pkgs.writeTextFile "sbom-metadata.json" (builtins.toJSON {
  runtime = builtins.map (p: {
    name = p.pname;  # Still fails during toJSON
    # ...
  }) runtimePackages;
})
```

**But this fails too** - same coercion issue.

**Alternative**: Write metadata during install phase:

```nix
# In build derivation
installPhase = ''
  # ... normal install ...

  # Write metadata file
  echo "$metadata" > $out/nix-metadata.json
'';
```

**Pros**:
- ✅ Metadata available in output
- ✅ Can query at SBOM generation time

**Cons**:
- ❌ Imperative (file I/O during build)
- ❌ Metadata not in passthru (can't discover without building)
- ❌ Pollutes output directory

### Solution 4: Accept Partial Solution (⚠️ Temporary)

Use name/version parsing from paths (Approach 2) and **accept missing `drvPath`**:

```json
{
  "name": "python3.11-pytest",
  "version": "7.4.4",
  "outPath": "/nix/store/...",
  "drvPath": ""  // Leave empty
}
```

**Impact**:
- Can still match ecosystem packages to Nix by name/version
- Can add `nix:purl` and `nix:output` properties
- Cannot add `nix:drv` property
- Cannot add `externalReference` (requires drv)

**Test impact**:
- Some tests would pass (traceability by name/version)
- Some tests would still fail (missing drv info)
- Better than current state, not complete solution

## Current Status

### What's Working

- ✅ `just build` - Fixed Nix expression syntax error
- ✅ `just test-sboms` - Fixed bundler environment
- ✅ SBOM generation - Base, runtime, app SBOMs work
- ✅ Container composition - Merges SBOMs correctly
- ✅ 136/145 test scenarios pass

### What's Not Working

- ❌ Nix traceability metadata
  - Missing `nix:purl` properties
  - Missing `nix:output` properties
  - Missing `nix:drv` properties
  - Missing `sbom:scope` properties
  - Missing `externalReference` entries

- ❌ Scope classification
  - Can't distinguish runtime vs dev-only packages
  - All packages treated as unknown scope

- ❌ 9/145 test scenarios fail

## Conclusion

The Nix traceability feature is blocked by a **fundamental Nix design limitation**: derivation objects cannot be serialized to JSON while preserving metadata.

The correct solution requires **upstream changes** to ecosystem package builders (poetry2nix, bundlerEnv) to expose serializable metadata.

Workarounds exist but all have significant drawbacks:
- Post-build queries break purity and declarativeness
- Name parsing provides partial solution
- Imperative file I/O violates Nix principles

For now, the project **accepts this limitation** and documents the challenge for future resolution.

## References

- Nix manual on derivations: https://nixos.org/manual/nix/stable/language/derivations.html
- poetry2nix repository: https://github.com/nix-community/poetry2nix
- Nix serialization behavior: https://nixos.org/manual/nix/stable/language/values.html#serialization
- SBOM traceability requirements: `compliance/sbom-tests/features/10_nix_traceability.feature`
