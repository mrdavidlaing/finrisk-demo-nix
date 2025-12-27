{
  description = "TransferX - Multi-Rail Funds Transfer Platform (Polyglot Microservices Demo)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix.url = "github:nix-community/poetry2nix";
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ poetry2nix.overlays.default ];
        };
        
        # Import service packages
        api-gateway = pkgs.callPackage ./release/api-gateway.nix { };
        kyc-service = pkgs.callPackage ./release/kyc-service.nix { };
        fee-service = pkgs.callPackage ./release/fee-service.nix { };
        sanctions-service = pkgs.callPackage ./release/sanctions-service.nix { };
        swift-gateway = pkgs.callPackage ./release/swift-gateway.nix { };
        crypto-transfer = pkgs.callPackage ./release/crypto-transfer.nix { };
        audit-service = pkgs.callPackage ./release/audit-service.nix { };
        web-portal = pkgs.callPackage ./release/web-portal.nix { };
        smoke-tests = pkgs.callPackage ./release/smoke-tests.nix { };

        services = {
          inherit
            api-gateway
            kyc-service
            fee-service
            sanctions-service
            swift-gateway
            crypto-transfer
            audit-service
            web-portal
            smoke-tests;
        };

        packageSets = import ./release/package-sets.nix {
          inherit pkgs services;
        };

        
        # Docker images
        api-gateway-image = pkgs.dockerTools.buildImage {
          name = "transferx/api-gateway";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${api-gateway}/bin/api-gateway" ];
            ExposedPorts = { "8080/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
          };
        };
        
        kyc-service-image = pkgs.dockerTools.buildImage {
          name = "transferx/kyc-service";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${kyc-service}/bin/KycService" ];
            ExposedPorts = { "8081/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
          };
        };
        
        fee-service-image = pkgs.dockerTools.buildImage {
          name = "transferx/fee-service";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${fee-service}/bin/fee-service" ];
            ExposedPorts = { "8082/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
          };
        };
        
        sanctions-service-image = pkgs.dockerTools.buildImage {
          name = "transferx/sanctions-service";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${sanctions-service}/bin/sanctions-service" ];
            ExposedPorts = { "8083/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
          };
        };
        
        swift-gateway-image = pkgs.dockerTools.buildImage {
          name = "transferx/swift-gateway";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp bin
            chmod 1777 tmp
            # Copy both binaries to /bin for easy access
            cp ${swift-gateway}/bin/mt103-generator bin/
            cp ${swift-gateway}/bin/swift-gateway-server bin/
          '';
          config = {
            Cmd = [ "/bin/swift-gateway-server" ];
            ExposedPorts = { "8086/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" "PORT=8086" "PATH=/bin" ];
          };
        };
        
        crypto-transfer-image = pkgs.dockerTools.buildImage {
          name = "transferx/crypto-transfer";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${crypto-transfer}/bin/crypto-transfer" ];
            ExposedPorts = { "8085/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
          };
        };
        
        audit-service-image = pkgs.dockerTools.buildImage {
          name = "transferx/audit-service";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${audit-service}/bin/audit-service-wrapper" ];
            ExposedPorts = { "8084/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
          };
        };
        
        web-portal-image = pkgs.dockerTools.buildImage {
          name = "transferx/web-portal";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${web-portal}/bin/web-portal" ];
            ExposedPorts = { "3000/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
          };
        };
        
        smoke-tests-image = pkgs.dockerTools.buildImage {
          name = "transferx/smoke-tests";
          tag = "latest";
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${smoke-tests}/bin/smoke-tests" ];
            ExposedPorts = { "8090/tcp" = {}; };
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
          };
        };
        
        # All services package
        all-services = pkgs.symlinkJoin {
          name = "all-services";
          paths = [
            api-gateway
            kyc-service
            fee-service
            sanctions-service
            swift-gateway
            crypto-transfer
            audit-service
            web-portal
            smoke-tests
          ];
        };
        
        # All images package
        all-images = pkgs.runCommand "all-images" {} ''
          mkdir -p $out
          ln -s ${api-gateway-image} $out/api-gateway.tar.gz
          ln -s ${kyc-service-image} $out/kyc-service.tar.gz
          ln -s ${fee-service-image} $out/fee-service.tar.gz
          ln -s ${sanctions-service-image} $out/sanctions-service.tar.gz
          ln -s ${swift-gateway-image} $out/swift-gateway.tar.gz
          ln -s ${crypto-transfer-image} $out/crypto-transfer.tar.gz
          ln -s ${audit-service-image} $out/audit-service.tar.gz
          ln -s ${web-portal-image} $out/web-portal.tar.gz
          ln -s ${smoke-tests-image} $out/smoke-tests.tar.gz
        '';


        # Legacy placeholder for SBOM directory (use generate-composed-sboms)
        all-sboms = pkgs.writeTextDir "sboms/README.md" ''
          # SBOMs

          Generate SBOMs locally:
          - nix run .#generate-sboms -- sboms
          - nix run .#generate-composed-sboms -- sboms
        '';
        
        generate-sboms = pkgs.writeShellScriptBin "generate-sboms" ''
          set -euo pipefail

          OUT_DIR="''${1:-sboms}"
          mkdir -p "$OUT_DIR"
          OUT_DIR="$(cd "$OUT_DIR" && pwd)"

          SERVICES="api-gateway kyc-service fee-service sanctions-service swift-gateway crypto-transfer audit-service web-portal smoke-tests"
          REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

          tmp="$(mktemp -d)"
          cleanup() {
            chmod -R u+w "$tmp" 2>/dev/null || true
            rm -rf "$tmp"
          }
          trap cleanup EXIT

          cd "$tmp"

          gen_sbomnix() {
            local name="$1"
            local store_path="$2"
            local out_file="$3"
            echo "[sbom] $name -> $out_file"
            ${pkgs.sbomnix}/bin/sbomnix "$store_path" --cdx "$out_file"
            rm -f sbom.spdx.json sbom.csv || true
          }

          gen_npm_sbom() {
            local name="$1"
            local src_dir="$2"
            local out_file="$3"
            echo "[sbom] npm $name -> $out_file"
            if [ -f "$src_dir/package.json" ]; then
              ${pkgs.syft}/bin/syft scan dir:"$src_dir" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate npm SBOM for $name, continuing without it" >&2
                # Create empty SBOM if syft fails
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no package.json found for $name, skipping npm SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          gen_maven_sbom() {
            local name="$1"
            local jar_path="$2"
            local out_file="$3"
            echo "[sbom] maven $name -> $out_file"
            if [ -f "$jar_path" ]; then
              # Syft can scan JAR files and extract Maven dependencies
              ${pkgs.syft}/bin/syft scan file:"$jar_path" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate Maven SBOM for $name, continuing without it" >&2
                # Create empty SBOM if syft fails
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no JAR file found at $jar_path for $name, skipping Maven SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          gen_dotnet_sbom() {
            local name="$1"
            local service_path="$2"
            local out_file="$3"
            echo "[sbom] dotnet $name -> $out_file"
            # Syft can scan .NET assemblies and extract NuGet dependencies
            # Try scanning the lib directory (where DLLs are typically stored)
            # or the entire service path
            if [ -d "$service_path/lib" ] || [ -d "$service_path" ]; then
              scan_path="$service_path"
              if [ -d "$service_path/lib" ]; then
                scan_path="$service_path/lib"
              fi
              ${pkgs.syft}/bin/syft scan dir:"$scan_path" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate .NET SBOM for $name, continuing without it" >&2
                # Create empty SBOM if syft fails
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no directory found at $service_path for $name, skipping .NET SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          gen_rust_sbom() {
            local name="$1"
            local src_dir="$2"
            local out_file="$3"
            echo "[sbom] rust $name -> $out_file"
            if [ -f "$src_dir/Cargo.toml" ] || [ -f "$src_dir/Cargo.lock" ]; then
              # Syft can scan Rust Cargo.toml/Cargo.lock files
              ${pkgs.syft}/bin/syft scan dir:"$src_dir" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate Rust SBOM for $name, continuing without it" >&2
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no Cargo.toml/Cargo.lock found for $name, skipping Rust SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          gen_go_sbom() {
            local name="$1"
            local src_dir="$2"
            local out_file="$3"
            echo "[sbom] go $name -> $out_file"
            if [ -f "$src_dir/go.mod" ]; then
              # Syft can scan Go go.mod/go.sum files
              ${pkgs.syft}/bin/syft scan dir:"$src_dir" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate Go SBOM for $name, continuing without it" >&2
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no go.mod found for $name, skipping Go SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          gen_perl_sbom() {
            local name="$1"
            local src_dir="$2"
            local out_file="$3"
            echo "[sbom] perl $name -> $out_file"
            if [ -f "$src_dir/Makefile.PL" ] || [ -f "$src_dir/cpanfile" ] || [ -f "$src_dir/META.json" ]; then
              # Syft can scan Perl Makefile.PL, cpanfile, or META.json files
              ${pkgs.syft}/bin/syft scan dir:"$src_dir" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate Perl SBOM for $name, continuing without it" >&2
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no Makefile.PL/cpanfile/META.json found for $name, skipping Perl SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          gen_python_sbom() {
            local name="$1"
            local src_dir="$2"
            local out_file="$3"
            echo "[sbom] python $name -> $out_file"
            if [ -f "$src_dir/pyproject.toml" ] || [ -f "$src_dir/requirements.txt" ] || [ -f "$src_dir/Pipfile" ] || [ -f "$src_dir/poetry.lock" ]; then
              # Syft can scan Python pyproject.toml, requirements.txt, Pipfile, or poetry.lock files
              ${pkgs.syft}/bin/syft scan dir:"$src_dir" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate Python SBOM for $name, continuing without it" >&2
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no pyproject.toml/requirements.txt/Pipfile/poetry.lock found for $name, skipping Python SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          gen_ruby_sbom() {
            local name="$1"
            local src_dir="$2"
            local out_file="$3"
            echo "[sbom] ruby $name -> $out_file"
            if [ -f "$src_dir/Gemfile" ] || [ -f "$src_dir/Gemfile.lock" ] || [ -f "$src_dir/gems.rb" ]; then
              # Syft can scan Ruby Gemfile, Gemfile.lock, or gems.rb files
              ${pkgs.syft}/bin/syft scan dir:"$src_dir" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate Ruby SBOM for $name, continuing without it" >&2
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no Gemfile/Gemfile.lock/gems.rb found for $name, skipping Ruby SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          merge_sboms() {
            local nix_sbom="$1"
            local deps_sbom="$2"
            local out_file="$3"
            echo "[sbom] merging Nix + dependencies SBOMs -> $out_file"
            ${pkgs.bash}/bin/bash ${./scripts/merge-cyclonedx.sh} "$nix_sbom" "$deps_sbom" "$out_file"
          }

          base_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#transferx-base-set)"
          gen_sbomnix "base" "$base_path" "$OUT_DIR/base.cdx.json"

          for rt in native node java dotnet python perl ruby; do
            rt_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#transferx-runtime-$rt)"
            gen_sbomnix "runtime-$rt" "$rt_path" "$OUT_DIR/runtime-$rt.cdx.json"
          done

          for svc in $SERVICES; do
            svc_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#$svc)"
            nix_sbom="$OUT_DIR/app-$svc-nix.cdx.json"
            gen_sbomnix "app-$svc (nix)" "$svc_path" "$nix_sbom"
            
            # For Node.js services, also generate npm SBOM and merge
            if [ "$svc" = "web-portal" ]; then
              npm_sbom="$OUT_DIR/app-$svc-npm.cdx.json"
              src_dir="$REPO_ROOT/services/$svc"
              gen_npm_sbom "app-$svc (npm)" "$src_dir" "$npm_sbom"
              merge_sboms "$nix_sbom" "$npm_sbom" "$OUT_DIR/app-$svc.cdx.json"
              rm -f "$nix_sbom" "$npm_sbom"
            # For Java/Maven services, extract Maven dependencies from JAR and merge
            elif [ "$svc" = "sanctions-service" ]; then
              # Find the JAR file in the Nix store path
              jar_file="$(find "$svc_path/share/java" -name "*.jar" 2>/dev/null | head -1)"
              if [ -n "$jar_file" ] && [ -f "$jar_file" ]; then
                maven_sbom="$OUT_DIR/app-$svc-maven.cdx.json"
                gen_maven_sbom "app-$svc (maven)" "$jar_file" "$maven_sbom"
                merge_sboms "$nix_sbom" "$maven_sbom" "$OUT_DIR/app-$svc.cdx.json"
                rm -f "$nix_sbom" "$maven_sbom"
              else
                echo "[sbom] warning: no JAR file found for $svc, using Nix SBOM only" >&2
                mv "$nix_sbom" "$OUT_DIR/app-$svc.cdx.json"
              fi
            # For .NET services, extract NuGet dependencies from source (better component detection)
            elif [ "$svc" = "kyc-service" ]; then
              dotnet_sbom="$OUT_DIR/app-$svc-dotnet.cdx.json"
              # Scan source directory for better component name matching (KycService.csproj -> KycService)
              src_dir="$REPO_ROOT/services/$svc"
              if [ -f "$src_dir/KycService.csproj" ] || [ -d "$svc_path/lib" ]; then
                # Try source first (better for component matching), fall back to built output
                if [ -f "$src_dir/KycService.csproj" ]; then
                  ${pkgs.syft}/bin/syft scan dir:"$src_dir" -o cyclonedx-json --output "cyclonedx-json=$dotnet_sbom" || {
                    echo "[sbom] warning: failed to generate .NET SBOM from source for $svc, trying built output..." >&2
                    gen_dotnet_sbom "app-$svc (dotnet)" "$svc_path" "$dotnet_sbom"
                  }
                else
                  gen_dotnet_sbom "app-$svc (dotnet)" "$svc_path" "$dotnet_sbom"
                fi
              else
                echo "[sbom] warning: no .csproj or lib directory found for $svc, skipping .NET SBOM" >&2
                echo '{"bomFormat":"CycloneDX","specVersion":"1.4","version":1,"components":[],"dependencies":[]}' > "$dotnet_sbom"
              fi
              merge_sboms "$nix_sbom" "$dotnet_sbom" "$OUT_DIR/app-$svc.cdx.json"
              rm -f "$nix_sbom" "$dotnet_sbom"
            # For Rust services, extract Cargo dependencies from source and merge
            elif [ "$svc" = "crypto-transfer" ]; then
              rust_sbom="$OUT_DIR/app-$svc-rust.cdx.json"
              src_dir="$REPO_ROOT/services/$svc"
              gen_rust_sbom "app-$svc (rust)" "$src_dir" "$rust_sbom"
              merge_sboms "$nix_sbom" "$rust_sbom" "$OUT_DIR/app-$svc.cdx.json"
              rm -f "$nix_sbom" "$rust_sbom"
            # For Go services, extract Go module dependencies from source and merge
            elif [ "$svc" = "api-gateway" ]; then
              go_sbom="$OUT_DIR/app-$svc-go.cdx.json"
              src_dir="$REPO_ROOT/services/$svc"
              gen_go_sbom "app-$svc (go)" "$src_dir" "$go_sbom"
              merge_sboms "$nix_sbom" "$go_sbom" "$OUT_DIR/app-$svc.cdx.json"
              rm -f "$nix_sbom" "$go_sbom"
            # For Perl services, extract Perl/CPAN dependencies from source and merge
            elif [ "$svc" = "audit-service" ]; then
              perl_sbom="$OUT_DIR/app-$svc-perl.cdx.json"
              src_dir="$REPO_ROOT/services/$svc"
              gen_perl_sbom "app-$svc (perl)" "$src_dir" "$perl_sbom"
              merge_sboms "$nix_sbom" "$perl_sbom" "$OUT_DIR/app-$svc.cdx.json"
              rm -f "$nix_sbom" "$perl_sbom"
            # For Python services, extract Python/PyPI dependencies from source and merge
            elif [ "$svc" = "fee-service" ]; then
              python_sbom="$OUT_DIR/app-$svc-python.cdx.json"
              src_dir="$REPO_ROOT/services/$svc"
              gen_python_sbom "app-$svc (python)" "$src_dir" "$python_sbom"
              merge_sboms "$nix_sbom" "$python_sbom" "$OUT_DIR/app-$svc.cdx.json"
              rm -f "$nix_sbom" "$python_sbom"
            # For Ruby services, extract Ruby/RubyGems dependencies from source and merge
            elif [ "$svc" = "smoke-tests" ]; then
              ruby_sbom="$OUT_DIR/app-$svc-ruby.cdx.json"
              src_dir="$REPO_ROOT/services/$svc"
              gen_ruby_sbom "app-$svc (ruby)" "$src_dir" "$ruby_sbom"
              merge_sboms "$nix_sbom" "$ruby_sbom" "$OUT_DIR/app-$svc.cdx.json"
              rm -f "$nix_sbom" "$ruby_sbom"
            else
              mv "$nix_sbom" "$OUT_DIR/app-$svc.cdx.json"
            fi
          done

          echo "[sbom] wrote layer SBOMs to $OUT_DIR"
        '';

        generate-composed-sboms = pkgs.writeShellScriptBin "generate-composed-sboms" ''
          set -euo pipefail

          OUT_DIR="''${1:-sboms}"
          mkdir -p "$OUT_DIR"
          OUT_DIR="$(cd "$OUT_DIR" && pwd)"

          SERVICES="api-gateway kyc-service fee-service sanctions-service swift-gateway crypto-transfer audit-service web-portal smoke-tests"

          "${generate-sboms}/bin/generate-sboms" "$OUT_DIR"

          runtime_for() {
            case "$1" in
              api-gateway|crypto-transfer|swift-gateway) echo "native" ;;
              kyc-service) echo "dotnet" ;;
              sanctions-service) echo "java" ;;
              web-portal) echo "node" ;;
              fee-service) echo "python" ;;
              audit-service) echo "perl" ;;
              smoke-tests) echo "ruby" ;;
              *) echo "native" ;;
            esac
          }

          export PATH="${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.jq}/bin:$PATH"
          export JQ="${pkgs.jq}/bin/jq"

          for svc in $SERVICES; do
            rt="$(runtime_for "$svc")"
            base="$OUT_DIR/base.cdx.json"
            runtime="$OUT_DIR/runtime-$rt.cdx.json"
            app="$OUT_DIR/app-$svc.cdx.json"
            out="$OUT_DIR/container-$svc.cdx.json"

            echo "[sbom] compose container-$svc (base + runtime-$rt + app-$svc)"
            ${pkgs.bash}/bin/bash ${./scripts/compose-cyclonedx.sh}               "$base" "$runtime" "$app" "$out"               "$svc" "transferx/$svc" "latest"
          done

          echo "[sbom] wrote container SBOMs to $OUT_DIR"
        '';


        
        # Vulnerability scanning script
        scan-all = pkgs.writeShellScriptBin "scan-all" ''
          set -e
          echo "Scanning all Docker images for vulnerabilities..."
          
          mkdir -p compliance/sboms/nix
          mkdir -p compliance/vulns
          
          # Load images if needed
          for img in ${api-gateway-image} ${kyc-service-image} ${fee-service-image} \
                     ${sanctions-service-image} ${swift-gateway-image} \
                     ${crypto-transfer-image} ${audit-service-image} ${web-portal-image} ${smoke-tests-image}; do
            if [ -f "$img" ]; then
              echo "Loading image: $img"
              docker load < "$img" || true
            fi
          done
          
          # Services list
          SERVICES="api-gateway kyc-service fee-service sanctions-service swift-gateway crypto-transfer audit-service web-portal smoke-tests"
          
          for service in $SERVICES; do
             echo "Processing $service..."
             
             # 1. Generate Container SBOM (Syft)
             echo "  Generating container SBOM..."
             ${pkgs.syft}/bin/syft "transferx/$service:latest" \
               -o cyclonedx-json \
               --file "compliance/sboms/$service.cdx.json"
               
             # 2. Scan for Vulnerabilities (Grype)
             echo "  Scanning for vulnerabilities..."
             ${pkgs.grype}/bin/grype "compliance/sboms/$service.cdx.json" \
               -o json \
               --file "compliance/vulns/$service.json"
          done
          
          # 3. Generate Nix-native SBOMs (sbomnix)
          # Note: This is simplified. In a real scenario, we'd target the derivation paths directly.
          # For demo purposes, we'll document this step.
          echo "Generating Nix-native SBOMs..."
          
          # Helper to generate sbomnix SBOM
          gen_nix_sbom() {
            name=$1
            path=$2
            echo "  Generating Nix SBOM for $name..."
            ${pkgs.sbomnix}/bin/sbomnix "$path" --cdx "compliance/sboms/nix/$name.cdx.json" || true
            rm -f sbom.spdx.json sbom.csv
          }
          
          gen_nix_sbom "api-gateway" "${api-gateway}"
          gen_nix_sbom "kyc-service" "${kyc-service}"
          gen_nix_sbom "fee-service" "${fee-service}"
          gen_nix_sbom "sanctions-service" "${sanctions-service}"
          gen_nix_sbom "swift-gateway" "${swift-gateway}"
          gen_nix_sbom "crypto-transfer" "${crypto-transfer}"
          gen_nix_sbom "audit-service" "${audit-service}"
          gen_nix_sbom "web-portal" "${web-portal}"
          gen_nix_sbom "smoke-tests" "${smoke-tests}"
          
          echo "Compliance artifacts generated in compliance/"
        '';
        
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Language toolchains
            nodejs_20
            go
            dotnetCorePackages.sdk_8_0
            python3
            poetry
            jdk17
            maven
            gnucobol.bin
            cargo
            rustc
            
            # Build tools
            nixpkgs-fmt
            git
            just
            
            # Compliance tools
            syft
            grype
            sbomnix

            # Container tools
            docker
            docker-compose
            
            # K8s tools (for future Helm phase)
            kubectl
            helm
            kind
          ];
          
          shellHook = ''
            echo "TransferX Development Environment"
            echo "================================="
            echo "Available services:"
            echo "  - web-portal (Next.js)"
            echo "  - api-gateway (Go)"
            echo "  - kyc-service (.NET)"
            echo "  - fee-service (Python)"
            echo "  - sanctions-service (Java)"
            echo "  - audit-service (Perl)"
            echo "  - swift-gateway (COBOL)"
            echo "  - crypto-transfer (Rust)"
            echo "  - smoke-tests (Ruby/Cucumber)"
            echo ""
            echo "Quick start: just --list"
            echo "Common commands:"
            echo "  just build        - Build all services"
            echo "  just up           - Build, load images, and start Docker Compose"
            echo "  just test-health  - Check service health"
            echo "  just scan         - Run compliance scans"
          '';
        };

        packages = {
          # Services
          inherit api-gateway kyc-service fee-service sanctions-service 
                  swift-gateway crypto-transfer audit-service web-portal smoke-tests;
          
          # Aggregated
          inherit all-services all-images all-sboms;

          # Package sets (base + runtimes)
          transferx-base-set = packageSets.base;
          transferx-runtime-native = packageSets.runtimes.native;
          transferx-runtime-node = packageSets.runtimes.node;
          transferx-runtime-java = packageSets.runtimes.java;
          transferx-runtime-dotnet = packageSets.runtimes.dotnet;
          transferx-runtime-python = packageSets.runtimes.python;
          transferx-runtime-perl = packageSets.runtimes.perl;
          transferx-runtime-ruby = packageSets.runtimes.ruby;

          # SBOM generation apps as packages
          inherit generate-sboms generate-composed-sboms;
          
          # Docker images
          inherit api-gateway-image kyc-service-image fee-service-image
                  sanctions-service-image swift-gateway-image crypto-transfer-image
                  audit-service-image web-portal-image smoke-tests-image;
        };
        
        apps = {
          scan-all = {
            type = "app";
            program = "${scan-all}/bin/scan-all";
          };

          generate-sboms = {
            type = "app";
            program = "${generate-sboms}/bin/generate-sboms";
          };

          generate-composed-sboms = {
            type = "app";
            program = "${generate-composed-sboms}/bin/generate-composed-sboms";
          };
          
          # Show what was built (even if cached)
          show-built = let
            script = pkgs.writeShellScriptBin "show-built" ''
              set -e
              echo "TransferX Services - Build Status"
              echo "=================================="
              echo ""
              
              # Build and show paths with status (suppress warnings)
              for service in api-gateway kyc-service fee-service sanctions-service swift-gateway crypto-transfer audit-service web-portal smoke-tests; do
                echo -n "  $service: "
                if path=$(nix build --no-link --print-out-paths .#$service 2>/dev/null); then
                  echo "$path"
                else
                  echo "FAILED"
                fi
              done
              
              echo ""
              echo "All services package:"
              if path=$(nix build --no-link --print-out-paths .#all-services 2>/dev/null); then
                echo "  $path"
              else
                echo "  (not built)"
              fi
              
              echo ""
              echo "Tip: Use 'nix build .#all-services --print-out-paths' to see paths directly"
              echo "     Use 'nix build .#all-services --print-build-logs' to see build logs"
            '';
          in {
            type = "app";
            program = "${script}/bin/show-built";
          };
        };
      }
    );
}

