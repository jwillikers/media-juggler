{ inputs }:
{
  unstablePackages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable { inherit (final) system; };
  };
  image_optim = _final: prev: {
    image_optim = prev.image_optim.override { withPngout = true; };
  };
  additionalPackages = _final: prev: {
    flexigif = prev.callPackage ./flexigif/package.nix { };
    imgdataopt = prev.callPackage ./imgdataopt/package.nix { };
    jpeg2png = prev.callPackage ./jpeg2png/package.nix { };
    jpegli = prev.callPackage ./jpegli/package.nix { };
    pdfsizeopt = prev.callPackage ./pdfsizeopt/package.nix { };
    sam2p = prev.callPackage ./sam2p/package.nix { };
    tif22pnm = prev.callPackage ./tif22pnm/package.nix { };
    minuimus = prev.callPackage ./minuimus/package.nix { withPngout = true; };
  };
  m4b-tool = inputs.m4b-tool.overlay;
}
