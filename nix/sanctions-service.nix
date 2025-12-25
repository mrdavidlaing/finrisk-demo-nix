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
    
    buildPhase = ''
      # Set up a local repository
      mkdir -p $out/.m2/repository
      
      # Perform a package build to download all dependencies and plugins
      # We use a custom local repo path
      mvn package -Dmaven.repo.local=$out/.m2/repository -DskipTests
      
      # Clean up the build artifacts from the deps derivation, keeping only the repo
      rm -rf target
    '';
    
    installPhase = "true";
    
    outputHashAlgo = "sha256";
    outputHash = "sha256-Wen+vA66gl5fJrDABw5kCiUWGATKEoSxe3NQn9hyVeQ="; # To be updated
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
