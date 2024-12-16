{
  ensureNewerSourcesForZipFilesHook,
  fetchFromGitHub,
  lib,
  python3,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "modify_epub";
  version = "1.8.5";

  src = fetchFromGitHub {
    owner = "kiwidude68";
    repo = "calibre_plugins";
    rev = "refs/tags/modify_epub-v${version}";
    hash = "sha256-4acs2c2ybNhAtWEaIeaubz3L7Kfrd20oqkZCIvjB0UQ=";
  };

  nativeBuildInputs = [ ensureNewerSourcesForZipFilesHook ];

  buildPhase = ''
    runHook preBuild
    (cd modify_epub && ${lib.getExe python3} ../common/build.py)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins "modify_epub/Modify ePub.zip"
    runHook postInstall
  '';

  meta = {
    description = "This plugin offers a way to perform certain modifications to your selected ePub files without performing a calibre conversion";
    homepage = "https://github.com/kiwidude68/calibre_plugins/tree/main/modify_epub";
    changelog = "https://github.com/kiwidude68/calibre_plugins/releases/tag/modify_epub-v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
