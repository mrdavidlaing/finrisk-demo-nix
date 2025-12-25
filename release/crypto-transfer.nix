{ pkgs, lib }:

pkgs.rustPlatform.buildRustPackage {
  pname = "crypto-transfer";
  version = "0.1.0";
  src = ../services/crypto-transfer;
  
  # Use cargoLock with the lock file
  cargoLock = {
    lockFile = ../services/crypto-transfer/Cargo.lock;
  };
  
  meta = with lib; {
    description = "TransferX Crypto Transfer Service";
    license = licenses.mit;
  };
}

