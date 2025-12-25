{ pkgs, lib }:

pkgs.poetry2nix.mkPoetryApplication {
  projectDir = ../services/fee-service;
  preferWheels = true;
  python = pkgs.python311;
  
  meta = with lib; {
    description = "TransferX Fee Service";
    license = licenses.mit;
  };
}
