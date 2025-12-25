{ pkgs, lib }:

pkgs.buildDotnetModule {
  pname = "kyc-service";
  version = "0.1.0";

  src = ../services/kyc-service;

  projectFile = "KycService.csproj";
  
  nugetDeps = ./kyc-service-deps.nix;

  dotnet-sdk = pkgs.dotnetCorePackages.sdk_8_0;
  dotnet-runtime = pkgs.dotnetCorePackages.aspnetcore_8_0;

  meta = with lib; {
    description = "TransferX KYC Service";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
