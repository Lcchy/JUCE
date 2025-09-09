{
  description = "Projucer build environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowInsecure = true;
          permittedInsecurePackages = [
            "libsoup-2.74.3"
          ];
        };
      };
    in {
      devShells.default = pkgs.mkShell {
        name = "projucer-dev";

        buildInputs = with pkgs; [
          # Core JUCE dependencies
          freetype
          alsa-lib
          webkitgtk_4_0
          curl
          gtk3
          jack2

          # X11 dependencies
          xorg.libX11
          xorg.libX11.dev
          xorg.libXext
          xorg.libXinerama
          xorg.xrandr
          xorg.libXcursor
          xorg.libXdmcp
          xorg.libXtst

          # Additional system dependencies
          pcre2
          pcre
          libuuid
          libselinux
          libsepol
          libthai
          libdatrie
          libpsl
          libxkbcommon
          libepoxy
          libsysprof-capture
          sqlite.dev

          # Font dependencies
          fontconfig
          dejavu_fonts
          liberation_ttf
          freefont_ttf

          # SSL/Network dependencies for curl
          openssl
          cacert
          curl.dev
          nghttp2
          libssh2
          zlib
          brotli
        ];

        nativeBuildInputs = with pkgs; [
          gnumake
          gcc11
          pkg-config
          cmake
          patchelf
          gdb
        ];

        # Explicit linking flags for JUCE
        NIX_LDFLAGS = toString [
          "-lX11"
          "-lXext"
          "-lXcursor"
          "-lXinerama"
          "-lXrandr"
          "-lfontconfig"
          "-lfreetype"
          "-lcurl"
          "-lssl"
          "-lcrypto"
        ];

        shellHook = ''
          # Font setup (fixes JUCE font assertions)
          export FONTCONFIG_FILE=${pkgs.fontconfig.out}/etc/fonts/fonts.conf
          export FONTCONFIG_PATH=${pkgs.fontconfig.out}/etc/fonts

          mkdir -p ~/.local/share/fonts ~/.fonts

          # Link specific fonts JUCE looks for by name
          ln -sf ${pkgs.dejavu_fonts}/share/fonts/truetype/* ~/.local/share/fonts/ 2>/dev/null || true
          ln -sf ${pkgs.liberation_ttf}/share/fonts/truetype/* ~/.local/share/fonts/ 2>/dev/null || true
          ln -sf ${pkgs.freefont_ttf}/share/fonts/truetype/* ~/.local/share/fonts/ 2>/dev/null || true
          ln -sf ~/.local/share/fonts/* ~/.fonts/ 2>/dev/null || true

          ${pkgs.fontconfig}/bin/fc-cache -f ~/.local/share/fonts

          # SSL/Curl setup (fixes JUCE network assertions)
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          export NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

          # Ensure curl can find its dependencies
          export LD_LIBRARY_PATH="${pkgs.curl.out}/lib:${pkgs.openssl.out}/lib:${pkgs.nghttp2.lib}/lib:${pkgs.libssh2}/lib:$LD_LIBRARY_PATH"

          # Wayland/X11 compatibility for Sway
          export WAYLAND_DISPLAY=''${WAYLAND_DISPLAY}
          export GDK_BACKEND=wayland,x11
          export QT_QPA_PLATFORM=wayland;xcb
          export DISPLAY=''${DISPLAY:-:0}

          # GTK theme
          export GTK_THEME=Adwaita

          # Verification tests
          echo "=== JUCE Environment Verification ==="

          # Test fonts
          echo "Font check:"
          for font in "DejaVu Serif" "Liberation Serif" "DejaVu Sans" "Liberation Sans"; do
            result=$(${pkgs.fontconfig}/bin/fc-match "$font" 2>/dev/null | cut -d: -f1)
            if echo "$result" | grep -q "$(echo "$font" | sed 's/ //g')"; then
              echo "  ✓ $font -> $result"
            else
              echo "  ✗ $font -> $result (fallback)"
            fi
          done

          # Test curl
          echo ""
          echo "Network check:"
          if ${pkgs.curl}/bin/curl -s -I https://httpbin.org/status/200 >/dev/null 2>&1; then
            echo "  ✓ Curl SSL/HTTPS working"
          else
            echo "  ✗ Curl SSL/HTTPS issue (may cause network assertions)"
          fi

          echo ""
          echo "JUCE Projucer development environment ready!"
          echo "Run: ./build/Projucer"
        '';
      };
    });
}
