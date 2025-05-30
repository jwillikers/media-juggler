{
  stdenv,
  lib,
  fetchFromGitHub,
  ghostscript_headless,
  libjpeg,
  makeWrapper,
  nix-update-script,
  netpbm,
  perl,
  tif22pnm,
  versionCheckHook,
  zip,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "sam2p";
  version = "0.49.4";

  src = fetchFromGitHub {
    owner = "pts";
    repo = "sam2p";
    tag = "v${finalAttrs.version}";
    hash = "sha256-wW2HLfZp4/F9n/qDlfGXHFUtANM8LcDPgNUoBrLxEAg=";
  };

  nativeBuildInputs = [
    ghostscript_headless
    libjpeg
    makeWrapper
    netpbm
    perl
    tif22pnm
    zip
  ];

  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 --target-directory=$out/bin sam2p
    wrapProgram $out/bin/sam2p \
      --prefix PATH : ${
        lib.makeBinPath [
          ghostscript_headless
          libjpeg
          netpbm
          tif22pnm
          zip
        ]
      }
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "A raster to PostScript/PDF image conversion program";
    homepage = "http://pts.50.hu/sam2p/";
    changelog = "https://github.com/pts/sam2p/blob/v${finalAttrs.version}/debian/changelog";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.all;
    maintainers = with lib.maintainers; [ jwillikers ];
    mainProgram = "sam2p";
  };
})
