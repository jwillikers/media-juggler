{
  automake,
  stdenv,
  lib,
  fetchurl,
  pkg-config,
  zlib,
  expat,
  openssl,
  autoconf,
  libjpeg,
  libpng,
  libtiff,
  freetype,
  fontconfig,
  libpaper,
  jbig2dec,
  libiconv,
  ijs,
  lcms2,
  callPackage,
  bash,
  buildPackages,
  openjpeg,
  fixDarwinDylibNames,
  dynamicDrivers ? true,

  # for passthru.tests
  graphicsmagick,
  imagemagick,
  libspectre,
  lilypond,
  pstoedit,
  python3,
}:

let
  fonts = stdenv.mkDerivation {
    name = "ghostscript-fonts";

    srcs = [
      (fetchurl {
        url = "mirror://sourceforge/gs-fonts/ghostscript-fonts-std-8.11.tar.gz";
        hash = "sha256-DrbzVhGfLkmyVjIQhS4X9X+dzFdV81Cmmkag1kGgxAE=";
      })
      (fetchurl {
        url = "mirror://gnu/ghostscript/gnu-gs-fonts-other-6.0.tar.gz";
        hash = "sha256-gUbMzEaZ/p2rhBRGvdFwOfR2nJA+zrVECRiLkgdUqrM=";
      })
      # ... add other fonts here
    ];

    installPhase = ''
      mkdir "$out"
      mv -v * "$out/"
    '';
  };
in
stdenv.mkDerivation {
  pname = "ghostscript_9_05_headless";
  version = "9.05";

  src = fetchurl {
    url = "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/ghostscript/ghostscript-9.05.tgz";
    hash = "sha256-WT9391hHBL353kFZighKQgjDrTuUCh3h+q+PWaFcwgc=";
  };

  # For debugging
  # dontStrip = true;
  # enableDebugging = true;

  patches = [
    ./urw-font-files.patch
    ./doc-no-ref.diff
    ./ghostscript-9.05-glibc-timeval.patch
    # https://github.com/chrstphrchvz/macports-ports/blob/197bfa253db6d2dcb589197fa99d2bd19793fa10/print/ghostscript/files/patch-base_fapi_ft.c.diff
    ./ghostscript-9.05-freetype-2.10.3.patch
    # https://github.com/chrstphrchvz/macports-ports/blob/197bfa253db6d2dcb589197fa99d2bd19793fa10/print/ghostscript/files/ghostpdl.git-06c920713e11.patch
    ./ghostpdl.git-06c920713e11.patch
  ];

  outputs = [
    "out"
    "man"
    # "doc"
    "fonts"
  ];

  enableParallelBuilding = true;

  depsBuildBuild = [
    buildPackages.stdenv.cc
  ];

  nativeBuildInputs = [
    pkg-config
    autoconf
    zlib
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin fixDarwinDylibNames
  # For version 9.05
  ++ [ automake ];

  buildInputs = [
    zlib
    expat
    openssl
    libjpeg
    libpng
    libtiff
    freetype
    fontconfig
    libpaper
    jbig2dec
    libiconv
    ijs
    lcms2
    bash
    openjpeg
  ];

  preConfigure = ''
    # https://ghostscript.com/doc/current/Make.htm
    export CCAUX=$CC_FOR_BUILD
    rm -rf jpeg libpng zlib jasper expat tiff lcms lcms2 lcms2mt jbig2dec freetype cups/libs ijs openjpeg

    sed "s@if ( test -f \$(INCLUDE)[^ ]* )@if ( true )@; s@INCLUDE=/usr/include@INCLUDE=/no-such-path@" -i base/unix-aux.mak
    sed "s@^ZLIBDIR=.*@ZLIBDIR=${zlib.dev}/include@" -i configure.ac

    autoreconf -i
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    export DARWIN_LDFLAGS_SO_PREFIX=$out/lib/
  '';

  configureFlags = [
    # Fallback to c17 since the c23 standard will break everything.
    "CFLAGS=-std=gnu17"
    "--with-system-libtiff"
    "--without-tesseract"
    "--without-x"
    "--disable-cups"
  ]
  ++ lib.optionals dynamicDrivers [
    "--enable-dynamic"
    "--disable-hidden-visibility"
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error -Wno-implicit-function-declaration -Wno-implicit-int -Wno-int-conversion -Wno-incompatible-pointer-types -Wno-missing-prototypes";

  # The buildsystem doesn't link zlib correctly, so it has to be added here for 9.05.
  NIX_LDFLAGS = "-lz";

  # make check does nothing useful
  doCheck = false;

  # don't build/install statically linked bin/gs
  buildFlags = [
    "so"
  ];
  installTargets = [ "soinstall" ];

  postInstall = ''
    ln -s gsc "$out"/bin/gs

    cp -r Resource "$out/share/ghostscript/9.05"

    mkdir -p $fonts/share/fonts
    cp -rv ${fonts}/* "$fonts/share/fonts/"
    ln -s "$fonts/share/fonts" "$out/share/ghostscript/fonts"
  '';

  # Parallel install is broken for version 9.05.
  enableParallelInstalling = false;

  # As of NixOS 25.11 the installCheckPhase fails with a segmentation fault for version 9.05.
  doInstallCheck = false;

  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/gs --version
    $out/bin/gsx --version
    pushd examples
    for f in *.{ps,eps,pdf}; do
      echo "Rendering $f"
      $out/bin/gs \
        -dNOPAUSE \
        -dBATCH \
        -sDEVICE=bitcmyk \
        -sOutputFile=/dev/null \
        -r600 \
        -dBufferSpace=100000 \
        $f
    done
    popd # examples

    runHook postInstallCheck
  '';

  passthru.tests = {
    test-corpus-render = callPackage ./test-corpus-render.nix { };
    inherit
      graphicsmagick
      imagemagick
      libspectre
      lilypond
      pstoedit
      ;
    inherit (python3.pkgs) matplotlib;
  };

  meta = {
    homepage = "https://www.ghostscript.com/";
    description = "PostScript interpreter (mainline version)";
    longDescription = ''
      Ghostscript is the name of a set of tools that provides (i) an
      interpreter for the PostScript language and the PDF file format,
      (ii) a set of C procedures (the Ghostscript library) that
      implement the graphics capabilities that appear as primitive
      operations in the PostScript language, and (iii) a wide variety
      of output drivers for various file formats and printers.
    '';
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.all;
    maintainers = with lib.maintainers; [ jwillikers ];
    mainProgram = "gs";
    # Totally insecure given it's effectively an ancient version.
    # Use only with trusted PDFs.
    insecure = true;
  };
}
