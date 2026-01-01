{ pkgs, lib }:

let
  # Evaluate all packages (runtime + dev) for SBOM traceability
  allPoetryPackages = pkgs.poetry2nix.mkPoetryPackages {
    projectDir = ../services/fee-service;
    python = pkgs.python311;
    preferWheels = true;
    groups = [ "main" "dev" ];  # Include dev dependencies for SBOM
  };

  # Build the application (runtime dependencies only)
  app = pkgs.poetry2nix.mkPoetryApplication {
    projectDir = ../services/fee-service;
    preferWheels = true;
    python = pkgs.python311;
    groups = [ "main" ];  # Runtime only
    
    meta = with lib; {
      description = "TransferX Fee Service";
      license = licenses.mit;
    };
  };

  # Helper to extract package metadata as JSON-serializable values
  extractPackageInfo = pkg: {
    name = builtins.toString (pkg.pname or pkg.name or "unknown");
    version = builtins.toString (pkg.version or "unknown");
    outPath = builtins.toString pkg.outPath;
    drvPath = builtins.toString pkg.drvPath;
  };

  # Get runtime packages from the built app
  runtimePackages = app.passthru.requiredPythonModules or [];
  
  # All packages from poetry (runtime + dev)
  allPackages = allPoetryPackages.poetryPackages;
  
  # Determine dev-only packages (in allPackages but not in runtimePackages)
  runtimePaths = builtins.map (p: p.outPath) runtimePackages;
  isDevOnly = pkg: !(builtins.elem pkg.outPath runtimePaths);
  devPackages = builtins.filter isDevOnly allPackages;

in app.overrideAttrs (oldAttrs: {
  passthru = (oldAttrs.passthru or {}) // {
    # Expose dependencies with scope for SBOM generation
    sbomDependencies = {
      runtime = builtins.map extractPackageInfo runtimePackages;
      dev-only = builtins.map extractPackageInfo devPackages;
      all = builtins.map extractPackageInfo (runtimePackages ++ devPackages);
    };
  };
})
