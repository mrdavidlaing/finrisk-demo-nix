{ pkgs, lib, stdenv, maven, jdk17, makeWrapper }:

let
  pname = "sanctions-service";
  version = "0.1.0";
  src = ../services/sanctions-service;

  # Fetch all dependencies into a local repository
  # This is a fixed-output derivation (FOD)
  deps = stdenv.mkDerivation {
    name = "${pname}-deps-${version}";
    inherit src;
    
    nativeBuildInputs = [ jdk17 maven ];
    
    # Set environment variables for deterministic Maven builds
    preBuild = ''
      export MAVEN_OPTS="-Dmaven.repo.local=$out/.m2/repository"
      export SOURCE_DATE_EPOCH=1
    '';
    
    buildPhase = ''
      # Set up a local repository
      mkdir -p $out/.m2/repository
      
      # Download all dependencies and plugins deterministically
      # Using validate phase ensures plugins are downloaded without building
      mvn validate \
        -Dmaven.repo.local=$out/.m2/repository \
        -DskipTests \
        --batch-mode \
        --errors \
        --fail-at-end
      
      # Also explicitly resolve dependencies and plugins to ensure completeness
      mvn dependency:resolve dependency:resolve-plugins \
        -Dmaven.repo.local=$out/.m2/repository \
        --batch-mode \
        --errors \
        --fail-at-end || true
      
      # Clean up any non-deterministic metadata files
      # Remove timestamp files and other metadata that can vary between builds
      find $out/.m2/repository -name "*.lastUpdated" -delete || true
      find $out/.m2/repository -name "_remote.repositories" -delete || true
      
      # Remove any build artifacts if they exist
      rm -rf target
    '';
    
    installPhase = "true";
    
    outputHashAlgo = "sha256";
    # To update the hash after making changes:
    # 1. Comment out or remove the outputHash line below
    # 2. Run: nix build -L .#sanctions-service 2>&1 | grep "got:"
    # 3. Update outputHash with the hash from the error message
    outputHash = "sha256-Wen+vA66gl5fJrDABw5kCiUWGATKEoSxe3NQn9hyVeQ=";
    outputHashMode = "recursive";
  };

in stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ jdk17 maven makeWrapper ];

  buildPhase = ''
    # Use the fetched dependencies
    # Copy them to a writable directory because Maven might try to write lock files etc.
    # actually --offline usually treats repo as read-only but let's see.
    # Usually we can just point to it.
    
    mvn package --offline -Dmaven.repo.local=${deps}/.m2/repository -DskipTests
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/java
    cp target/${pname}-${version}.jar $out/share/java/
    
    makeWrapper ${jdk17}/bin/java $out/bin/${pname} \
      --add-flags "-jar $out/share/java/${pname}-${version}.jar"
  '';

  meta = with lib; {
    description = "TransferX Sanctions Service";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
