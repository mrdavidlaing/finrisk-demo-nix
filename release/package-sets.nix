{ pkgs
, services
}:

let
  mkSet = { name, paths }:
    pkgs.buildEnv {
      inherit name paths;
      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
    };

  base = mkSet {
    name = "transferx-base-set";
    paths = with pkgs; [
      bash
      coreutils
      cacert
      tzdata
    ];
  };

  runtimes = {
    native = mkSet { name = "transferx-runtime-native"; paths = [ ]; };

    node = mkSet {
      name = "transferx-runtime-node";
      paths = [ pkgs.nodejs_20 ];
    };

    java = mkSet {
      name = "transferx-runtime-java";
      paths = [
        (pkgs.jdk17_headless or pkgs.jdk17)
      ];
    };

    dotnet = mkSet {
      name = "transferx-runtime-dotnet";
      paths = [ pkgs.dotnetCorePackages.aspnetcore_8_0 ];
    };

    python = mkSet {
      name = "transferx-runtime-python";
      paths = [ pkgs.python311 ];
    };

    perl = mkSet {
      name = "transferx-runtime-perl";
      paths = with pkgs; [ perl perlPackages.JSON ];
    };

    ruby = mkSet {
      name = "transferx-runtime-ruby";
      paths = [ pkgs.ruby_3_3 ];
    };
  };

  apps = {
    api-gateway = services.api-gateway;
    kyc-service = services.kyc-service;
    fee-service = services.fee-service;
    sanctions-service = services.sanctions-service;
    swift-gateway = services.swift-gateway;
    crypto-transfer = services.crypto-transfer;
    audit-service = services.audit-service;
    web-portal = services.web-portal;
    smoke-tests = services.smoke-tests;
  };

  serviceRuntimes = {
    api-gateway = runtimes.native;
    crypto-transfer = runtimes.native;
    swift-gateway = runtimes.native;

    kyc-service = runtimes.dotnet;
    sanctions-service = runtimes.java;
    web-portal = runtimes.node;

    fee-service = runtimes.python;
    audit-service = runtimes.perl;
    smoke-tests = runtimes.ruby;
  };
in
{
  inherit base runtimes apps serviceRuntimes;
}
