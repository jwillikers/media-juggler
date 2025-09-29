{
  stdenv,
  lib,
  advancecomp,
  efficient-compression-tool,
  fetchFromGitHub,
  fetchurl,
  ghostscript_headless,
  imgdataopt,
  jbig2enc,
  makeWrapper,
  nix-update-script,
  optipng,
  withPngout ? false,
  pngout, # disabled by default because it's unfree
  python2,
  sam2p,
  versionCheckHook,
  zopfli,
  # patch
  image_optim,
  oxipng,
  pngquant,
  pngcrush,
  # For GhostScript
  automake,
  zlib,
}:
let
  ghostscript_9_05_headless = ghostscript_headless.overrideAttrs (
    _finalAttrs: previousAttrs: {
      version = "9.05";

      src = fetchurl {
        url = "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/ghostscript/ghostscript-9.05.tgz";
        hash = "sha256-WT9391hHBL353kFZighKQgjDrTuUCh3h+q+PWaFcwgc=";
      };

      patches = [
        ./urw-font-files.patch
        ./doc-no-ref.diff
        ./ghostscript-9.05-glibc-timeval.patch
        ./ghostscript-9.05-freetype-2.10.3.patch
      ];

      nativeBuildInputs = previousAttrs.nativeBuildInputs ++ [ automake ];

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

      configureFlags = previousAttrs.configureFlags ++ [
        "--without-x"
        "--disable-cups"
      ];

      # Fallback to c17 since the c23 standard will break everything.
      env.NIX_CFLAGS_COMPILE = "-std=c17 -Wno-error -Wno-implicit-function-declaration -Wno-implicit-int -Wno-int-conversion -Wno-incompatible-pointer-types";

      # The buildsystem doesn't link zlib correctly, so it has to be added here.
      NIX_LDFLAGS = "-lz";

      # Parallel install is broken.
      enableParallelInstalling = false;

      # The doc output is empty, so it is removed here.
      outputs = [
        "out"
        "man"
        "fonts"
      ];

      meta.insecure = true;
    }
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "pdfsizeopt";
  version = "2023-04-18";

  src = fetchFromGitHub {
    owner = "pts";
    repo = "pdfsizeopt";
    tag = finalAttrs.version;
    hash = "sha256-kp61nxzxCzjZZ5ojHf3M0+CnG/L6CxfoipgwkmWHx5o=";
  };

  patches = [
    ./1980-zip.patch
    ./ect.patch
    ./image_optim.patch
  ];

  postPatch = ''
    rm pdfsizeopt.single
    substituteInPlace lib/pdfsizeopt/main.py \
      --replace-fail "rev or 'UNKNOWN'" "'${finalAttrs.version}'"
    substituteInPlace mksingle.py \
      --replace-fail "os.chdir(os.path.dirname(__file__))" ""
  '';

  nativeBuildInputs = [
    advancecomp
    ghostscript_9_05_headless
    imgdataopt
    jbig2enc
    makeWrapper
    python2
    sam2p
  ];

  buildPhase = ''
    runHook preBuild
    python2 mksingle.py
    runHook postBuild
  '';

  checkPhase = ''
    runHook preCheck
    python2 pdfsizeopt_test.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm0755 pdfsizeopt.single $out/bin/pdfsizeopt
    wrapProgram $out/bin/pdfsizeopt \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            advancecomp
            efficient-compression-tool
            ghostscript_9_05_headless
            imgdataopt
            jbig2enc
            optipng
            pngout
            python2
            sam2p
            zopfli
            # patch
            image_optim
            oxipng
            pngquant
            pngcrush
          ]
          ++ lib.optionals withPngout [ pngout ]
        )
      }
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "A program for converting large PDF files to small ones, without decreasing visual quality or removing interactive features";
    homepage = "https://github.com/pts/pdfsizeopt";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.all;
    maintainers = with lib.maintainers; [ jwillikers ];
    mainProgram = "pdfsizeopt";
  };
})
