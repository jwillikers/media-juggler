{ inputs }:
{
  cbconvert = _final: prev: {
    # cbconvert won't build with 1.26.3 and newer due to a bug in go-fitz:
    # https://github.com/gen2brain/go-fitz/issues/143
    cbconvert =
      let
        mupdf-headless = prev.mupdf-headless.overrideAttrs (_prevAttrs: {
          version = "1.25.3";
          src = prev.fetchurl {
            url = "https://mupdf.com/downloads/archive/mupdf-1.25.3-source.tar.gz";
            hash = "sha256-uXTXBqloBTPRBLQRIiTHvz3pPye+fKQbS/tRVSYk8Kk=";
          };
          patches = [
            # Upstream makefile does not work with system deps on macOS by default, so
            # we reuse the Linux section instead.
            (prev.fetchpatch2 {
              url = "https://raw.githubusercontent.com/NixOS/nixpkgs/refs/heads/nixos-25.05/pkgs/by-name/mu/mupdf/fix-darwin-system-deps.patch";
              hash = "sha256-e0lAQwXHRw0gPATvRMltjKfvlvdf8pb73nLnvQqNPeY=";
            })
            # Upstream C++ wrap script only defines fixed-sized integers on macOS but
            # this is required on aarch64-linux too.
            (prev.fetchpatch2 {
              url = "https://raw.githubusercontent.com/NixOS/nixpkgs/refs/heads/nixos-25.05/pkgs/by-name/mu/mupdf/fix-cpp-build.patch";
              hash = "sha256-gmJTxn1+xBMjiSxsusWUTrSZ932T/dioIsAxsAuip8w=";
            })
          ];
        });
      in
      prev.cbconvert.overrideAttrs (prevAttrs: {
        buildInputs = (prev.lib.lists.remove prev.mupdf-headless prevAttrs.buildInputs) ++ [
          mupdf-headless
        ];
      });
  };
  image_optim = _final: prev: {
    image_optim = prev.image_optim.override { withPngout = true; };
  };
  m4b-tool = inputs.m4b-tool.overlay;
  media-juggler = _final: prev: {
    calibre-plugins = prev.recurseIntoAttrs (prev.callPackage ./calibre-plugins { });
    flexigif = prev.callPackage ./flexigif/package.nix { };
    imgdataopt = prev.callPackage ./imgdataopt/package.nix { };
    jpeg2png = prev.callPackage ./jpeg2png/package.nix { };
    jpegli = prev.callPackage ./jpegli/package.nix { };
    media-juggler = prev.callPackage ./media-juggler/package.nix { };
    minuimus = prev.callPackage ./minuimus/package.nix { withPngout = true; };
    pdfsizeopt = prev.callPackage ./pdfsizeopt/package.nix { };
    sam2p = prev.callPackage ./sam2p/package.nix { };
    tif22pnm = prev.callPackage ./tif22pnm/package.nix { };
  };
}
