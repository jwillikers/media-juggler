{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
  zip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "embedcomicmetadata";
  version = "1.5.0-unstable-2023-04-05";

  src = fetchFromGitHub {
    owner = "dickloraine";
    repo = "EmbedComicMetadata";
    rev = "caa41a8a5d298c7cd02851647a8bcb61d17ce197";
    hash = "sha256-DnzyWRGyDkDRM1bVoeeI9bUj08c1gH457XYpY0hYOY4=";
  };

  nativeBuildInputs = [ zip ];

  buildPhase = ''
    runHook preBuild
    zip --recurse-paths EmbedComicMetadata *
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins EmbedComicMetadata.zip
    runHook postInstall
  '';

  meta = {
    homepage = "https://www.mobileread.com/forums/showthread.php?t=264710";
    changelog = "https://github.com/dickloraine/EmbedComicMetadata/releases/tag/v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = with lib.licenses; [ gpl3Only ];
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
