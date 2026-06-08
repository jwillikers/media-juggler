{ inputs }:
{
  # image_optim = _final: prev: {
  #   image_optim = prev.image_optim.override { withPngout = true; };
  # };
  efficient-compression-tool = _final: prev: {
    efficient-compression-tool = prev.efficient-compression-tool.overrideAttrs (_prevAttrs: {
      patches = [
        # from https://github.com/fhanau/Efficient-Compression-Tool/issues/145
        ./ect-gcc-15-O3-fix.patch
      ];
    });
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
        };
      in
      self;
    python3Packages = final.python3.pkgs;
  };
  media-juggler = final: prev: rec {
    # Enable ZOPFLI support in QPDF
    qpdf = prev.qpdf.overrideAttrs (prevAttrs: {
      buildInputs = prevAttrs.buildInputs ++ [ final.zopfli ];
      cmakeFlags = prevAttrs.cmakeFlags ++ [ (prev.lib.cmakeBool "ZOPFLI" true) ];
    });
    calibre-plugins = prev.lib.recurseIntoAttrs (prev.callPackage ./calibre-plugins { });
    flexigif = prev.callPackage ./flexigif/package.nix { };
    imgdataopt = prev.callPackage ./imgdataopt/package.nix { };
    isbntools = prev.callPackage ./isbntools/package.nix { };
    jpeg2png = prev.callPackage ./jpeg2png/package.nix { };
    jpegli = prev.callPackage ./jpegli/package.nix { };
    ghostscript_9_05_headless = prev.callPackage ./ghostscript_9_05_headless/package.nix { };
    media-juggler = prev.callPackage ./media-juggler/package.nix {
      inherit media-juggler-png-optimizer;
    };
    media-juggler-png-optimizer = prev.callPackage ./media-juggler-png-optimizer/package.nix { };
    minuimus = prev.callPackage ./minuimus/package.nix {
      inherit media-juggler-png-optimizer;
      withPngout = false;
    };
    pdfsizeopt = prev.callPackage ./pdfsizeopt/package.nix {
      inherit media-juggler-png-optimizer;
      withPngout = false;
    };
    sam2p = prev.callPackage ./sam2p/package.nix { };
    tif22pnm = prev.callPackage ./tif22pnm/package.nix { };
  };
}
