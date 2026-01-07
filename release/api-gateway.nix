{ pkgs, lib }:

pkgs.buildGoModule {
  pname = "api-gateway";
  version = "0.1.0";
  src = ../services/api-gateway;
  
  vendorHash = "sha256-XC7KhRUDTyJuZwtnGJ2oZMGrHK1FqKgEp+8Kj7zeYjM=";
  
  meta = with lib; {
    description = "TransferX API Gateway";
    license = licenses.mit;
  };
}

