{ pkgs, lib }:

pkgs.stdenv.mkDerivation {
  pname = "swift-gateway";
  version = "0.1.0";
  src = ../services/swift-gateway;
  
  buildInputs = with pkgs; [ gnucobol.bin ];
  
  buildPhase = ''
    cobc -x -o mt103-generator mt103-generator.cob
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp mt103-generator $out/bin/
    cp wrapper.sh $out/bin/swift-gateway
    chmod +x $out/bin/swift-gateway
    
    # Fix wrapper to use the compiled binary
    substituteInPlace $out/bin/swift-gateway \
      --replace 'mt103-generator' "$out/bin/mt103-generator"
  '';
  
  meta = with lib; {
    description = "TransferX SWIFT Gateway (COBOL)";
    license = licenses.mit;
  };
}

