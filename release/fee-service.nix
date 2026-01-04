{ pkgs, lib }:

let
  # Import shared SBOM traceability utilities
  traceability = import ../lib/sbom/nix-traceability.nix;

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

  # Get runtime packages from the built app
  runtimePackages = app.passthru.requiredPythonModules or [];
  
  # All packages from poetry (runtime + dev)
  allPackages = allPoetryPackages.poetryPackages;
  
  # Determine dev-only packages (in allPackages but not in runtimePackages)
  # Use unsafeDiscardStringContext for comparison to avoid context issues
  runtimePaths = builtins.map (p: builtins.unsafeDiscardStringContext (toString p)) runtimePackages;
  isDevOnly = pkg: !(builtins.elem (builtins.unsafeDiscardStringContext (toString pkg)) runtimePaths);
  devPackages = builtins.filter isDevOnly allPackages;

in app.overrideAttrs (oldAttrs: {
  passthru = (oldAttrs.passthru or {}) // {
    # Expose dependencies with scope for SBOM generation
    sbomDependencies = traceability.makeSbomDependencies {
      runtime = runtimePackages;
      devOnly = devPackages;
    };
  };
})
