{ pkgs, lib }:

pkgs.buildNpmPackage {
  pname = "web-portal";
  version = "0.1.0";
  src = ../services/web-portal;
  
  npmDepsHash = "sha256-BadUbQolv/irQwzkKd7ePGLVvzkrqVwvhXTsFLCH/NU=";
  
  # Next.js standalone build
  buildPhase = ''
    npm run build
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    
    # Copy standalone server
    if [ -d .next/standalone ]; then
      cp -r .next/standalone/* $out/
    else
      # Fallback (should not happen if next.config.js is correct)
      cp -r .next $out/.next
    fi
    
    # Copy runtime build output under .next.
    #
    # In practice, even with output=standalone, Next expects multiple manifests
    # under $PWD/.next at runtime (BUILD_ID, build-manifest.json, pages-manifest.json, etc).
    # The simplest reliable approach is to copy the non-cache parts of .next/.
    mkdir -p $out/.next
    if [ -d .next ]; then
      shopt -s dotglob
      for p in .next/*; do
        base="$(basename "$p")"
        if [ "$base" = "cache" ] || [ "$base" = "standalone" ]; then
          continue
        fi
        cp -r "$p" "$out/.next/"
      done
      shopt -u dotglob
    fi
    if [ -d public ]; then
      cp -r public $out/public
    fi
    
    # Create wrapper script
    cat > $out/bin/web-portal <<EOF
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.nodejs}/bin/node $out/server.js
    EOF
    chmod +x $out/bin/web-portal
  '';
  
  meta = with lib; {
    description = "TransferX Web Portal";
    license = licenses.mit;
  };
}
