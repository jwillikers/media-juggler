{
  ensureNewerSourcesForZipFilesHook,
  fetchFromGitHub,
  lib,
  python3,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "goodreads";
  version = "1.8.4";

  src = fetchFromGitHub {
    owner = "kiwidude68";
    repo = "calibre_plugins";
    rev = "refs/tags/goodreads-${version}";
    hash = "sha256-zd03c5IQUAo8wTVpvaYL9s86jR4e7Prt/IepZbXg/0k=";
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
