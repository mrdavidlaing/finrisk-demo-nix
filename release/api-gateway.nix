{ pkgs, lib }:

pkgs.buildGoModule {
  pname = "api-gateway";
  version = "0.1.0";
  src = ../services/api-gateway;
  
  vendorHash = "sha256-Zx03iHfwo0vqKbGA2ZV0UIvN7fH+YpsXdwsWoCQsw8U=";
  
  meta = with lib; {
    description = "TransferX API Gateway";
    license = licenses.mit;
  };
}

