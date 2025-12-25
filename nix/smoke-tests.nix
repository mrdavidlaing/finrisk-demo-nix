{ pkgs, lib }:

let
  ruby = pkgs.ruby_3_3;
  bundler = pkgs.bundler.override { inherit ruby; };
  
  # Install all gems in a fixed-output derivation
  # This ensures all gems are installed during the Nix build
  gems = pkgs.stdenv.mkDerivation {
    name = "smoke-tests-gems";
    src = ../services/smoke-tests;
    
    nativeBuildInputs = [ ruby bundler ];
    
    buildPhase = ''
      export HOME=$TMPDIR
      export GEM_HOME=$out
      export GEM_PATH=$out
      export PATH="${ruby}/bin:$PATH"
      
      # Install bundler 2.7.2 to a deterministic location
      BUNDLER_DIR=$TMPDIR/bundler-install
      ${ruby}/bin/gem install bundler -v 2.7.2 --install-dir $BUNDLER_DIR --no-document --no-user-install
      # Fix shebang in bundle script
      sed -i "1s|.*|#!${ruby}/bin/ruby|" $BUNDLER_DIR/bin/bundle || true
      export PATH="$BUNDLER_DIR/bin:${ruby}/bin:$PATH"
      
      # Install gems directly from Gemfile.lock, bypassing bundler entirely
      # This avoids the bundler version conflict issue
      if [ -f Gemfile.lock ]; then
        echo "Installing gems directly from Gemfile.lock..."
        # Extract gem names and versions from Gemfile.lock, sort for determinism
        # Format: "    gem-name (version)"
        GEM_LIST=$(grep -E "^\s+[a-zA-Z0-9_-]+ \(" Gemfile.lock | sed 's/^[[:space:]]*\([a-zA-Z0-9_-]*\).*(\([^)]*\)).*/\1:\2/' | sort -u)
        # Build install command with all gems at once for determinism
        GEM_INSTALL_CMD="${ruby}/bin/gem install"
        echo "$GEM_LIST" | while IFS=: read GEM_NAME GEM_VERSION; do
          if [ -n "$GEM_NAME" ] && [ -n "$GEM_VERSION" ] && [ "$GEM_NAME" != "BUNDLED" ]; then
            GEM_INSTALL_CMD="$GEM_INSTALL_CMD $GEM_NAME -v $GEM_VERSION"
          fi
        done
        # Install all gems at once
        $GEM_INSTALL_CMD --install-dir $out --no-document --conservative || {
          # If batch install fails, try individual installs
          echo "$GEM_LIST" | while IFS=: read GEM_NAME GEM_VERSION; do
            if [ -n "$GEM_NAME" ] && [ -n "$GEM_VERSION" ] && [ "$GEM_NAME" != "BUNDLED" ]; then
              ${ruby}/bin/gem install "$GEM_NAME" -v "$GEM_VERSION" --install-dir $out --no-document --conservative || true
            fi
          done
        }
      else
        # Fallback: install main gems if Gemfile.lock doesn't exist
        echo "Gemfile.lock not found, installing main gems..."
        ${ruby}/bin/gem install sinatra -v 3.2.0 --install-dir $out --no-document || true
        ${ruby}/bin/gem install puma -v 6.4.2 --install-dir $out --no-document || true
        ${ruby}/bin/gem install cucumber -v 9.0.0 --install-dir $out --no-document || true
        ${ruby}/bin/gem install faraday -v 2.9.0 --install-dir $out --no-document || true
        ${ruby}/bin/gem install rspec-expectations -v 3.12.3 --install-dir $out --no-document || true
      fi
      
      # Verify gems were installed
      if ! find $out -name "*.gemspec" 2>/dev/null | head -1 | grep -q .; then
        echo "ERROR: No gems were installed!"
        exit 1
      fi
    '';
    
    # This is a fixed-output derivation - the hash will be computed
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-dgalxAjec9P3Wgv4PKxljxOaW2C9HTQlb8AcoBvdKOg=";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "smoke-tests";
  version = "0.1.0";
  src = ../services/smoke-tests;
  
  buildInputs = [ ruby ];
  
  installPhase = ''
    mkdir -p $out/bin $out/share/smoke-tests
    cp -r . $out/share/smoke-tests/
    
    # Create wrapper that uses the pre-installed gems
    cat > $out/bin/smoke-tests <<EOF
    #!${pkgs.bash}/bin/bash
    export GEM_HOME="${gems}"
    export GEM_PATH="${gems}"
    export PATH="${ruby}/bin:${bundler}/bin:\$PATH"
    cd $out/share/smoke-tests
    exec bundle exec ruby app.rb
    EOF
    chmod +x $out/bin/smoke-tests
  '';
  
  meta = with lib; {
    description = "TransferX Smoke Tests Service";
    license = licenses.mit;
  };
}

