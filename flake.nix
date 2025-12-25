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
        api-gateway = pkgs.callPackage ./nix/api-gateway.nix { };
        kyc-service = pkgs.callPackage ./nix/kyc-service.nix { };
        fee-service = pkgs.callPackage ./nix/fee-service.nix { };
        sanctions-service = pkgs.callPackage ./nix/sanctions-service.nix { };
        swift-gateway = pkgs.callPackage ./nix/swift-gateway.nix { };
        crypto-transfer = pkgs.callPackage ./nix/crypto-transfer.nix { };
        audit-service = pkgs.callPackage ./nix/audit-service.nix { };
        web-portal = pkgs.callPackage ./nix/web-portal.nix { };
        smoke-tests = pkgs.callPackage ./nix/smoke-tests.nix { };
        
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
            mkdir -p tmp
            chmod 1777 tmp
          '';
          config = {
            Cmd = [ "${swift-gateway}/bin/swift-gateway" ];
            Env = [ "HOME=/tmp" "TMPDIR=/tmp" ];
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
        
        # SBOM generation (mock - in production use cyclonedx-cli)
        all-sboms = pkgs.writeTextDir "sboms/README.md" ''
          # SBOMs Directory
          
          SBOMs for each service are generated here using syft and sbomnix.
          
          Services:
          - api-gateway
          - kyc-service
          - fee-service
          - sanctions-service
          - swift-gateway
          - crypto-transfer
          - audit-service
          - web-portal
          - smoke-tests
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

