{
  description = "TransferX - Multi-Rail Funds Transfer Platform (Polyglot Microservices Demo)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix.url = "github:nix-community/poetry2nix";
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix }:
    let
      # Service registry - single source of truth for service metadata
      # This is top-level (not system-specific) since it's just metadata
      serviceRegistry = import ./services.nix {
        lib = nixpkgs.lib;
      };
    in
    (flake-utils.lib.eachDefaultSystem (system:
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

        # Shared JQ utilities for SBOM scripts
        jqUtils = import ./lib/sbom/jq-utils.nix { inherit pkgs; };

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

          SERVICES="${serviceRegistry.serviceList}"
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

          # Normalize SBOM specVersion to 1.6
          normalize_sbom_version() {
            local sbom_file="$1"
            ${pkgs.jq}/bin/jq '.specVersion = "1.6"' "$sbom_file" > "$sbom_file.tmp" && mv "$sbom_file.tmp" "$sbom_file"
          }

          # Generic language SBOM generator (replaces 8 language-specific functions)
          gen_lang_sbom() {
            local lang="$1"     # Language: npm, maven, dotnet, rust, go, perl, python, ruby
            local name="$2"     # Display name for logging
            local service="$3"  # Service name (for path lookups)
            local out_file="$4" # Output SBOM file

            echo "[sbom] $lang $name -> $out_file"

            # Define manifest files for each language
            case "$lang" in
              npm)    manifests="package.json" ;;
              maven)  manifests="pom.xml" ;;  # Will use JAR file instead
              dotnet) manifests="*.csproj" ;;
              rust)   manifests="Cargo.toml Cargo.lock" ;;
              go)     manifests="go.mod" ;;
              perl)   manifests="Makefile.PL cpanfile META.json" ;;
              python) manifests="pyproject.toml requirements.txt Pipfile poetry.lock" ;;
              ruby)   manifests="Gemfile Gemfile.lock gems.rb" ;;
              *)      echo "[sbom] error: unknown language: $lang" >&2; return 1 ;;
            esac

            # Special handling for maven: find and scan JAR file
            if [ "$lang" = "maven" ]; then
              svc_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#$service)"
              jar_file="$(find "$svc_path/share/java" -name "*.jar" 2>/dev/null | head -1)"
              if [ -n "$jar_file" ] && [ -f "$jar_file" ]; then
                ${pkgs.syft}/bin/syft scan file:"$jar_file" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                  echo "[sbom] warning: failed to generate Maven SBOM for $name, continuing without it" >&2
                  echo '{"bomFormat":"CycloneDX","specVersion":"1.6","version":1,"components":[],"dependencies":[]}' > "$out_file"
                }
              else
                echo "[sbom] warning: no JAR file found for $service, skipping Maven SBOM" >&2
                echo '{"bomFormat":"CycloneDX","specVersion":"1.6","version":1,"components":[],"dependencies":[]}' > "$out_file"
              fi
              return
            fi

            # For all other languages: scan source directory
            src_dir="$REPO_ROOT/services/$service"

            # Check if any manifest file exists
            found=false
            for manifest in $manifests; do
              # Handle glob patterns like *.csproj
              if ls "$src_dir"/$manifest > /dev/null 2>&1; then
                found=true
                break
              fi
            done

            if [ "$found" = "true" ]; then
              ${pkgs.syft}/bin/syft scan dir:"$src_dir" -o cyclonedx-json --output "cyclonedx-json=$out_file" || {
                echo "[sbom] warning: failed to generate $lang SBOM for $name, continuing without it" >&2
                echo '{"bomFormat":"CycloneDX","specVersion":"1.6","version":1,"components":[],"dependencies":[]}' > "$out_file"
              }
            else
              echo "[sbom] warning: no manifest files ($manifests) found for $service, skipping $lang SBOM" >&2
              echo '{"bomFormat":"CycloneDX","specVersion":"1.6","version":1,"components":[],"dependencies":[]}' > "$out_file"
            fi
          }

          merge_sboms() {
            local nix_sbom="$1"
            local deps_sbom="$2"
            local out_file="$3"
            echo "[sbom] merging Nix + dependencies SBOMs -> $out_file"
            export JQ_UTILS="${jqUtils}"
            ${pkgs.bash}/bin/bash ${./scripts/merge-cyclonedx.sh} "$nix_sbom" "$deps_sbom" "$out_file"
          }

          base_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#transferx-base-set)"
          gen_sbomnix "base" "$base_path" "$OUT_DIR/base.cdx.json"
          normalize_sbom_version "$OUT_DIR/base.cdx.json"
          ${pkgs.python3}/bin/python3 ${./lib/sbom/layer-tagger.py} base "$OUT_DIR/base.cdx.json"

          for rt in native node java dotnet python perl ruby; do
            rt_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#transferx-runtime-$rt)"
            gen_sbomnix "runtime-$rt" "$rt_path" "$OUT_DIR/runtime-$rt.cdx.json"
            normalize_sbom_version "$OUT_DIR/runtime-$rt.cdx.json"
          done
          # Tag all runtime SBOMs with layer=runtime
          ${pkgs.python3}/bin/python3 ${./lib/sbom/layer-tagger.py} runtime "$OUT_DIR"/runtime-*.cdx.json

          # Data-driven app SBOM generation using service registry
          for svc in $SERVICES; do
            svc_path="$(nix build --no-link --print-out-paths "$REPO_ROOT"#$svc)"
            nix_sbom="$OUT_DIR/app-$svc-nix.cdx.json"
            gen_sbomnix "app-$svc (nix)" "$svc_path" "$nix_sbom"
            normalize_sbom_version "$nix_sbom"

            # Get language from service registry
            lang=$(nix eval --raw "$REPO_ROOT#serviceRegistry.services.$svc.language" 2>/dev/null || echo "native")

            # Generate language-specific SBOM and merge if not native/cobol
            if [ "$lang" != "native" ] && [ "$lang" != "cobol" ]; then
              lang_sbom="$OUT_DIR/app-$svc-$lang.cdx.json"
              gen_lang_sbom "$lang" "app-$svc ($lang)" "$svc" "$lang_sbom"
              merge_sboms "$nix_sbom" "$lang_sbom" "$OUT_DIR/app-$svc.cdx.json"
              rm -f "$nix_sbom" "$lang_sbom"
            else
              # Native/COBOL services: just use Nix SBOM
              mv "$nix_sbom" "$OUT_DIR/app-$svc.cdx.json"
            fi
          done

          # Tag all app SBOMs with layer=app
          ${pkgs.python3}/bin/python3 ${./lib/sbom/layer-tagger.py} app "$OUT_DIR"/app-*.cdx.json

          # Filter unwanted components (CI configs, etc.) from app SBOMs
          ${pkgs.python3}/bin/python3 ${./lib/sbom/component-filter.py} "$OUT_DIR"/app-*.cdx.json

          # Deduplicate bom-refs in app SBOMs
          ${pkgs.python3}/bin/python3 ${./lib/sbom/dedup.py} "$OUT_DIR"/app-*.cdx.json

          echo "[sbom] wrote layer SBOMs to $OUT_DIR"
        '';

        generate-composed-sboms = pkgs.writeShellScriptBin "generate-composed-sboms" ''
          set -euo pipefail

          OUT_DIR="''${1:-sboms}"
          mkdir -p "$OUT_DIR"
          OUT_DIR="$(cd "$OUT_DIR" && pwd)"

          SERVICES="${serviceRegistry.serviceList}"

          "${generate-sboms}/bin/generate-sboms" "$OUT_DIR"

          export PATH="${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.jq}/bin:$PATH"
          export JQ="${pkgs.jq}/bin/jq"

          for svc in $SERVICES; do
            # Get runtime from service registry
            case "$svc" in
              ${pkgs.lib.concatMapStringsSep "\n              " (name: "${name}) rt=\"${serviceRegistry.services.${name}.runtime}\" ;;") serviceRegistry.serviceNames}
              *) rt="native" ;;
            esac
            base="$OUT_DIR/base.cdx.json"
            runtime="$OUT_DIR/runtime-$rt.cdx.json"
            app="$OUT_DIR/app-$svc.cdx.json"
            out="$OUT_DIR/container-$svc.cdx.json"

            echo "[sbom] compose container-$svc (base + runtime-$rt + app-$svc)"
            export JQ_UTILS="${jqUtils}"
            ${pkgs.bash}/bin/bash ${./scripts/compose-cyclonedx.sh}               "$base" "$runtime" "$app" "$out"               "$svc" "transferx/$svc" "latest"
          done

          # Filter unwanted components from container SBOMs
          ${pkgs.python3}/bin/python3 ${./lib/sbom/component-filter.py} "$OUT_DIR"/container-*.cdx.json

          # Fix CPE vendors and normalize versions in container SBOMs
          ${pkgs.python3}/bin/python3 ${./lib/sbom/cpe-fixer.py} "$OUT_DIR"/container-*.cdx.json

          # Deduplicate bom-refs in container SBOMs
          ${pkgs.python3}/bin/python3 ${./lib/sbom/dedup.py} "$OUT_DIR"/container-*.cdx.json

          # Ensure all components have dependency entries
          ${pkgs.python3}/bin/python3 ${./lib/sbom/ensure-dependency-entries.py} "$OUT_DIR"/container-*.cdx.json

          echo "[sbom] wrote container SBOMs to $OUT_DIR"
        '';

        # SBOM test runner
        sbom-test-runner = pkgs.writeShellScriptBin "sbom-test-runner" ''
          set -euo pipefail

          SBOM_DIR="''${1:-compliance/sboms}"
          PROFILE="''${2:-ci}"

          cd ${self}/compliance/sbom-tests

          # Install dependencies if needed
          if [ ! -d .bundle ]; then
            ${pkgs.bundler}/bin/bundle install --path .bundle
          fi

          # Run tests
          ${pkgs.bundler}/bin/bundle exec cucumber --profile "$PROFILE"
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
          SERVICES="${serviceRegistry.serviceList}"

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
            python3Packages.pyyaml
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

            # SBOM test dependencies
            ruby_3_3
            bundler
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

          # SBOM testing
          inherit sbom-test-runner;

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

          test-sboms = {
            type = "app";
            program = "${sbom-test-runner}/bin/sbom-test-runner";
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
    )) // {
      # Top-level outputs (not system-specific)
      inherit serviceRegistry;
    };
}

