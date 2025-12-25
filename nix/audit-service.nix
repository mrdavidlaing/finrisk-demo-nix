{ pkgs, lib }:

pkgs.stdenv.mkDerivation {
  pname = "audit-service";
  version = "0.1.0";
  src = ../services/audit-service;
  
  buildInputs = with pkgs; [ 
    perl
    perlPackages.JSON
  ];
  
  buildPhase = ''
    # Make script executable
    chmod +x audit-service.pl
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp audit-service.pl $out/bin/audit-service
    chmod +x $out/bin/audit-service
    
    # Create wrapper that sets up Perl environment
    cat > $out/bin/audit-service-wrapper <<'EOF'
    #!${pkgs.bash}/bin/bash
    export PERL5LIB=${PERL5LIB:+$PERL5LIB:}${pkgs.perlPackages.JSON}/lib/perl5/site_perl
    exec ${pkgs.perl}/bin/perl $out/bin/audit-service
    EOF
    substituteInPlace $out/bin/audit-service-wrapper \
      --replace '${pkgs.bash}' "${pkgs.bash}" \
      --replace '${pkgs.perlPackages.JSON}' "${pkgs.perlPackages.JSON}" \
      --replace '${pkgs.perl}' "${pkgs.perl}" \
      --replace '$out' "$out"
    chmod +x $out/bin/audit-service-wrapper
  '';
  
  meta = with lib; {
    description = "TransferX Audit Service (Perl)";
    license = licenses.mit;
  };
}

