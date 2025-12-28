{ lib }:
let
  # Service definition helper
  mkService = {
    name,
    runtime,
    language,
    manifestPatterns ? [],
    port ? null,
    description ? ""
  }: {
    inherit name runtime language manifestPatterns port description;
  };

  # All services defined in one place
  services = {
    api-gateway = mkService {
      name = "api-gateway";
      runtime = "native";
      language = "go";
      manifestPatterns = [ "go.mod" "go.sum" ];
      port = 8080;
      description = "API Gateway (Go - statically compiled)";
    };

    kyc-service = mkService {
      name = "kyc-service";
      runtime = "dotnet";
      language = "dotnet";
      manifestPatterns = [ "*.csproj" "KycService.csproj" ];
      port = 8081;
      description = "KYC Service (.NET Core)";
    };

    fee-service = mkService {
      name = "fee-service";
      runtime = "python";
      language = "python";
      manifestPatterns = [ "pyproject.toml" "requirements.txt" "Pipfile" "poetry.lock" ];
      port = 8082;
      description = "Fee Service (Python/FastAPI)";
    };

    sanctions-service = mkService {
      name = "sanctions-service";
      runtime = "java";
      language = "maven";
      manifestPatterns = [ "pom.xml" ];
      port = 8083;
      description = "Sanctions Service (Java/Spring Boot)";
    };

    audit-service = mkService {
      name = "audit-service";
      runtime = "perl";
      language = "perl";
      manifestPatterns = [ "Makefile.PL" "cpanfile" "META.json" "META.yml" ];
      port = 8084;
      description = "Audit Service (Perl)";
    };

    crypto-transfer = mkService {
      name = "crypto-transfer";
      runtime = "native";
      language = "rust";
      manifestPatterns = [ "Cargo.toml" "Cargo.lock" ];
      port = 8085;
      description = "Crypto Transfer (Rust - statically compiled)";
    };

    swift-gateway = mkService {
      name = "swift-gateway";
      runtime = "native";
      language = "cobol";
      manifestPatterns = [];
      port = 8086;
      description = "SWIFT Gateway (COBOL - statically compiled)";
    };

    web-portal = mkService {
      name = "web-portal";
      runtime = "node";
      language = "npm";
      manifestPatterns = [ "package.json" "package-lock.json" ];
      port = 3000;
      description = "Web Portal (Next.js)";
    };

    smoke-tests = mkService {
      name = "smoke-tests";
      runtime = "ruby";
      language = "ruby";
      manifestPatterns = [ "Gemfile" "Gemfile.lock" "gems.rb" ];
      port = 8090;
      description = "Smoke Tests (Ruby/Cucumber)";
    };
  };

  # Derived values
  serviceNames = builtins.attrNames services;

  # Space-separated service list for bash scripts
  serviceList = lib.concatStringsSep " " serviceNames;

  # Service to runtime mapping
  runtimeMap = lib.mapAttrs (name: svc: svc.runtime) services;

  # JSON array of service names for CI
  serviceNamesJson = builtins.toJSON serviceNames;

  # Get runtime for a service
  getRuntimeFor = serviceName:
    if builtins.hasAttr serviceName services
    then services.${serviceName}.runtime
    else "native";  # default fallback

  # Get language for a service
  getLanguageFor = serviceName:
    if builtins.hasAttr serviceName services
    then services.${serviceName}.language
    else "native";  # default fallback

  # Get manifest patterns for a service
  getManifestPatternsFor = serviceName:
    if builtins.hasAttr serviceName services
    then services.${serviceName}.manifestPatterns
    else [];

in
{
  inherit services serviceNames serviceList runtimeMap serviceNamesJson;
  inherit getRuntimeFor getLanguageFor getManifestPatternsFor;
}
