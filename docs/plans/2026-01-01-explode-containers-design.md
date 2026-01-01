# Container Filesystem Explorer Design

## Overview

Create an easy way to explore Docker container filesystems in VS Code by extracting the Nix-built container images to a temporary directory structure that can be browsed with VS Code's file tree explorer.

## Problem

Container SBOMs are generated automatically, but there's no easy way to cross-check them against the actual files that went into the containers. Understanding the exact filesystem structure of each container would help validate SBOM accuracy and understand what's being deployed.

## Solution

Extract the tar.gz files produced by `nix build .#all-images` to a `tmp/containers/` directory where each service has its own subdirectory containing its complete filesystem.

## File Structure

After running `just explode-containers`, the structure will be:

```
tmp/
  containers/
    api-gateway/
      bin/
        api-gateway
      etc/
      lib/
      nix/
      ...
    kyc-service/
      bin/
        KycService
      ...
    (7 more services)
```

The `tmp/` directory is gitignored to prevent committing extracted filesystems.

## Implementation

### Script: `scripts/explode-containers.sh`

**Flow:**
1. Check if `result/` exists (contains tar.gz from `nix build .#all-images`)
2. If not present, run `nix build .#all-images`
3. Remove existing `tmp/containers/` directory (clean extraction)
4. Create fresh `tmp/containers/` directory
5. For each tar.gz in `result/`:
   - Extract service name from filename (e.g., `transferx-api-gateway.tar.gz` → `api-gateway`)
   - Create service directory in `tmp/containers/`
   - Extract tar.gz contents to service directory
6. Print completion message

**Error Handling:**
- Use `set -euo pipefail` for robust error handling
- Fail fast on missing files or extraction errors

### Justfile Integration

Add recipe:
```justfile
explode-containers:
    ./scripts/explode-containers.sh
```

### Git Configuration

Add to `.gitignore`:
```
tmp/
```

## Workflow

1. Build container images (if not already built):
   ```bash
   just build-images
   ```
2. Extract filesystems:
   ```bash
   just explode-containers
   ```
3. Open `tmp/containers/` in VS Code and explore file trees

## Benefits

- **Simple**: Single command to extract all container filesystems
- **Clean**: Always starts fresh, no leftover files from previous extractions
- **Git-friendly**: `tmp/` is gitignored, no accidental commits
- **Reusable**: Script can be called independently of justfile
- **Accurate**: Uses the exact tar.gz files that get loaded into Docker

## Future Enhancements (Not in MVP)

- Add `--service` flag to extract only specific services
- Generate diff between two service filesystems
- Cross-reference files with SBOM components automatically
