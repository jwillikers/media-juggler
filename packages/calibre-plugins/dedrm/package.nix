{
  ensureNewerSourcesForZipFilesHook,
  fetchFromGitHub,
  lib,
  python3,
  stdenvNoCC,
  unzip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "dedrm";
  version = "10.0.9-unstable-2024-11-10";

  src = fetchFromGitHub {
    owner = "noDRM";
    repo = "DeDRM_tools";
    rev = "7379b453199ed1ba91bf3a4ce4875d5ed3c309a9";
    hash = "sha256-Hq/DBYeJ2urJtxG+MiO2L8TGZ9/kLue1DXbG4/KJFhc=";
  };

  nativeBuildInputs = [
    ensureNewerSourcesForZipFilesHook
    python3
  ];

  buildPhase = ''
    runHook preBuild
    ${lib.getExe python3} make_release.py
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    ${lib.getExe unzip} DeDRM_tools.zip -d out
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins out/DeDRM_plugin.zip out/Obok_plugin.zip
    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/noDRM/DeDRM_tools";
    changelog = "https://github.com/noDRM/DeDRM_tools/releases/tag/v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = with lib.licenses; [ gpl3Only ];
  };
}
