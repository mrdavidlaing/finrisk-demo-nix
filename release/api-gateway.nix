{ pkgs, lib }:

pkgs.buildGoModule {
  pname = "api-gateway";
  version = "0.1.0";
  src = ../services/api-gateway;
  
  vendorHash = "sha256-cdr/WiWQL+kZ3JhFwFDJP1JBupx3jaH9Y4UbkLIMpFc=";
  
  meta = with lib; {
    description = "TransferX API Gateway";
    license = licenses.mit;
  };
}

