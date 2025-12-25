{ pkgs, lib }:

pkgs.stdenv.mkDerivation {
  pname = "swift-gateway";
  version = "0.1.0";
  src = builtins.path {
    path = ../services/swift-gateway;
    name = "swift-gateway";
    filter = path: type: true; # Include all files
  };
  
  buildInputs = with pkgs; [ 
    gnucobol.bin
    libmicrohttpd
    json_c
    pkg-config
  ];
  
  nativeBuildInputs = with pkgs; [ gcc ];
  
  buildPhase = ''
    # Build COBOL binary
    cobc -x -o mt103-generator mt103-generator.cob
    
    # Build C HTTP server
    # Use pkg-config to get correct compiler and linker flags
    gcc -o swift-gateway-server server.c \
        $(pkg-config --cflags --libs libmicrohttpd json-c) \
        -std=c99 -Wall -Wextra
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp mt103-generator $out/bin/
    cp swift-gateway-server $out/bin/
    cp wrapper.sh $out/bin/swift-gateway
    chmod +x $out/bin/swift-gateway
    
    # Fix wrapper to use the compiled binary
    substituteInPlace $out/bin/swift-gateway \
      --replace 'mt103-generator' "$out/bin/mt103-generator"
  '';
  
  meta = with lib; {
    description = "TransferX SWIFT Gateway (COBOL + C HTTP wrapper)";
    license = licenses.mit;
  };
}

