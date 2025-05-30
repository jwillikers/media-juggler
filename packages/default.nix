{ pkgs, ... }:
rec {
  flexigif = pkgs.callPackage ./flexigif/package.nix { };
  imgdataopt = pkgs.callPackage ./imgdataopt/package.nix { };
  jpeg2png = pkgs.callPackage ./jpeg2png/package.nix { };
  minuimus = pkgs.callPackage ./minuimus/package.nix {
    inherit
      flexigif
      imgdataopt
      jpeg2png
      pdfsizeopt
      sam2p
      tif22pnm
      ;
    withPngout = true;
  };
  pdfsizeopt = pkgs.callPackage ./pdfsizeopt/package.nix { inherit imgdataopt sam2p; };
  sam2p = pkgs.callPackage ./sam2p/package.nix { inherit tif22pnm; };
  tif22pnm = pkgs.callPackage ./tif22pnm/package.nix { inherit tif22pnm; };
  calibrePlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./calibre-plugins { });
  media-juggler = pkgs.callPackage ./media-juggler/package.nix { inherit minuimus; };
}
