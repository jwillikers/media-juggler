{ inputs }:
{
  image_optim = _final: prev: {
    image_optim = prev.image_optim.override { withPngout = true; };
  };
  m4b-tool = inputs.m4b-tool.overlay;
  isbnlib2 = final: prev: {
    pythonPackagesOverlays = (prev.pythonPackagesOverlays or [ ]) ++ [
      (python-final: _python-prev: {
        isbnlib = python-final.callPackage ./isbnlib2/package.nix { };
      })
    ];
    python3 =
      let
        self = prev.python3.override {
          inherit self;
          packageOverrides = prev.lib.composeManyExtensions final.pythonPackagesOverlays;
        }; in
      self;
    python3Packages = final.python3.pkgs;
  };
  media-juggler = _final: prev: {
    calibre-plugins = prev.lib.recurseIntoAttrs (prev.callPackage ./calibre-plugins { });
    flexigif = prev.callPackage ./flexigif/package.nix { };
    imgdataopt = prev.callPackage ./imgdataopt/package.nix { };
    isbntools = prev.callPackage ./isbntools/package.nix { };
    jpeg2png = prev.callPackage ./jpeg2png/package.nix { };
    jpegli = prev.callPackage ./jpegli/package.nix { };
    media-juggler = prev.callPackage ./media-juggler/package.nix { };
    minuimus = prev.callPackage ./minuimus/package.nix { withPngout = true; };
    pdfsizeopt = prev.callPackage ./pdfsizeopt/package.nix { };
    sam2p = prev.callPackage ./sam2p/package.nix { };
    tif22pnm = prev.callPackage ./tif22pnm/package.nix { };
  };
}
