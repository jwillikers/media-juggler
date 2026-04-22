{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
  zip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "embedcomicmetadata";
  version = "1.5.0-unstable-2025-08-09";

  src = fetchFromGitHub {
    owner = "dickloraine";
    repo = "EmbedComicMetadata";
    rev = "4c686fcd0c33cb353c569dacb7c4d1fcd4f8696a";
    hash = "sha256-IOCzB6xQhHAUL9XdJrVkvs7eSGXAq9SquBBbbSw0swk=";
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
