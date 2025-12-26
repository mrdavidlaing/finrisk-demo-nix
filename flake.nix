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

          base_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#transferx-base-set)"
          gen_sbomnix "base" "$base_path" "$OUT_DIR/base.cdx.json"

          for rt in native node java dotnet python perl ruby; do
            rt_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#transferx-runtime-$rt)"
            gen_sbomnix "runtime-$rt" "$rt_path" "$OUT_DIR/runtime-$rt.cdx.json"
          done

          for svc in $SERVICES; do
            svc_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#$svc)"
            gen_sbomnix "app-$svc" "$svc_path" "$OUT_DIR/app-$svc.cdx.json"
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

