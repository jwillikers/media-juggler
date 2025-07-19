{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
  zip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "comicvine";
  version = "0.14.2";

  src = fetchFromGitHub {
    owner = "jbbandos";
    repo = "calibre-comicvine";
    rev = "refs/tags/v${version}";
    hash = "sha256-gOwjijWIcRl7Qe1VfN4HxaYUyIka2FgZYxbVLNm6jMQ=";
  };

  nativeBuildInputs = [ zip ];

  buildPhase = ''
    runHook preBuild
    zip Comicvine -@ < MANIFEST
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins Comicvine.zip
    runHook postInstall
  '';

  meta = {
    homepage = "https://www.mobileread.com/forums/showthread.php?p=4237667";
    changelog = "https://github.com/jbbandos/calibre-comicvine/releases/tag/v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = with lib.licenses; [ mit ];
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
