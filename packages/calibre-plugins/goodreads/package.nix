{
  ensureNewerSourcesForZipFilesHook,
  fetchFromGitHub,
  lib,
  python3,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "goodreads";
  version = "1.8.2";

  src = fetchFromGitHub {
    owner = "kiwidude68";
    repo = "calibre_plugins";
    rev = "refs/tags/goodreads-v${version}";
    hash = "sha256-SPMOxEP7HM8/q2H80l5REcRlGjgmPIvDSbmyjUTlufc=";
  };

  nativeBuildInputs = [ ensureNewerSourcesForZipFilesHook ];

  buildPhase = ''
    runHook preBuild
    (cd goodreads && ${lib.getExe python3} ../common/build.py)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins goodreads/Goodreads.zip
    runHook postInstall
  '';

  meta = {
    description = "This plugin allows Calibre to read book information from goodreads.com";
    homepage = "https://github.com/kiwidude68/calibre_plugins/tree/main/goodreads";
    changelog = "https://github.com/kiwidude68/calibre_plugins/releases/tag/goodreads-v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
