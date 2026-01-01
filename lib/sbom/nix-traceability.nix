# Nix SBOM Traceability Library
# ==============================
# Provides utilities for extracting package metadata from Nix store paths
# for inclusion in CycloneDX SBOMs.
#
# The core challenge: When Nix serializes derivation objects to JSON, they
# get coerced to their store paths (strings-with-context), losing metadata.
# This library recovers that metadata using Nix builtins.

{
  # ===========================================================================
  # extractPackageInfo: Extract metadata from a Nix package for SBOM generation
  # ===========================================================================
  #
  # Takes a Nix package (derivation or store path string) and extracts:
  #   - name: Package name (parsed from store path, or override if provided)
  #   - version: Package version (parsed from store path)
  #   - out_path: The output store path (context-free string)
  #   - drv_path: The derivation path (context-free string)
  #
  # How it works:
  #   1. Uses builtins.getContext to extract the .drv path from the string context
  #   2. Uses builtins.parseDrvName on the filename to extract name/version
  #   3. Uses builtins.unsafeDiscardStringContext to make strings JSON-serializable
  #
  # CRITICAL: We use "out_path" and "drv_path" instead of "outPath" and "drvPath"
  # because Nix has special handling for attribute sets containing "outPath" - it
  # treats them as derivation-like and coerces them to the path during JSON serialization.
  #
  # Arguments:
  #   pkg: A Nix package (derivation) or store path string
  #   nameOverride: (optional) Override the parsed name with an explicit value
  #
  # Example usage:
  #   extractPackageInfo { } pkg
  #   extractPackageInfo { nameOverride = "my-package"; } pkg
  # ===========================================================================
  
  extractPackageInfo = { nameOverride ? null }: pkg:
    let
      # Get the store path as a string (still has context at this point)
      pathStr = toString pkg;
      
      # Extract drv path from string context before it's lost
      ctx = builtins.getContext pathStr;
      drvPathVal = let keys = builtins.attrNames ctx; in
        if keys == [] then "" else builtins.elemAt keys 0;
      
      # Parse name/version from store path filename
      # Format: /nix/store/<32-char-hash>-<name>-<version>
      base = builtins.baseNameOf pathStr;
      nameWithVersion = builtins.substring 33 (-1) base;  # Skip hash (32 chars) + dash
      
      # CRITICAL: Discard context BEFORE parsing to avoid serialization errors
      cleanNameWithVersion = builtins.unsafeDiscardStringContext nameWithVersion;
      parsed = builtins.parseDrvName cleanNameWithVersion;
      
      # Use override name if provided, otherwise use parsed name
      finalName = if nameOverride != null then nameOverride else parsed.name;
    in {
      name = finalName;
      version = parsed.version;
      # Use "out_path" and "drv_path" to avoid Nix's special "outPath" coercion
      out_path = builtins.unsafeDiscardStringContext pathStr;
      drv_path = builtins.unsafeDiscardStringContext drvPathVal;
    };

  # ===========================================================================
  # mapPackagesToSbomDeps: Map a list of packages to SBOM dependency format
  # ===========================================================================
  #
  # Convenience function to map a list of packages using extractPackageInfo.
  #
  # Arguments:
  #   packages: List of Nix packages (derivations)
  #
  # Returns: List of { name, version, out_path, drv_path } records
  # ===========================================================================
  
  mapPackagesToSbomDeps = packages:
    builtins.map (extractPackageInfo { }) packages;

  # ===========================================================================
  # makeSbomDependencies: Create the standard sbomDependencies passthru structure
  # ===========================================================================
  #
  # Creates the { runtime, dev-only, all } structure expected by add-nix-traceability.py
  #
  # Arguments:
  #   runtime: List of runtime dependency packages
  #   devOnly: List of dev-only dependency packages (default: [])
  #
  # Returns: { runtime, dev-only, all } attribute set
  # ===========================================================================
  
  makeSbomDependencies = { runtime, devOnly ? [] }:
    let
      extract = extractPackageInfo { };
    in {
      runtime = builtins.map extract runtime;
      "dev-only" = builtins.map extract devOnly;
      all = builtins.map extract (runtime ++ devOnly);
    };
}

