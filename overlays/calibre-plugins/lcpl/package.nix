{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
  zip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "lcpl";
  version = "0.0.5";

  src = fetchFromGitHub {
    owner = "Leseratte10";
    repo = "lcpl-calibre-plugin";
    rev = "06d3a1040b1aa1ed6d83094819960833356b4e3c";
    hash = "sha256-HvBI4ex/a0BjGaUMGUhimD51ZBhvRcuD9GQmRhO1Mq0=";
  };

  nativeBuildInputs = [
    zip
  ];

  buildPhase = ''
    runHook preBuild
    bash ./bundle_calibre_plugin.sh
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins calibre-plugin.zip
    runHook postInstall
  '';

  meta = {
    description = "Calibre plugin for LCPL->EPUB and LCPL->PDF conversion";
    homepage = "https://www.mobileread.com/forums/showthread.php?t=342165";
    changelog = "https://github.com/Leseratte10/lcpl-calibre-plugin/releases/tag/v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = with lib.licenses; [ gpl3Plus ];
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
