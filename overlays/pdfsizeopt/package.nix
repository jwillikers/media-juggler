{
  stdenv,
  lib,
  advancecomp,
  efficient-compression-tool,
  fetchFromGitHub,
  ghostscript_9_05_headless,
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
}:
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
