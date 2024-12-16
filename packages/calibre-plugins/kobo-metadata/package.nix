{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
  zip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "kobo-metadata";
  version = "1.9.1";

  src = fetchFromGitHub {
    owner = "NotSimone";
    repo = "Kobo-Metadata";
    rev = "tags/refs/${version}";
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [ zip ];

  buildPhase = ''
    runHook preBuild
    zip --recurse-paths KoboMetadata *
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins KoboMetadata.zip
    runHook postInstall
  '';

  meta = {
    description = "Fetch metadata for Calibre from Kobo.";
    homepage = "https://github.com/NotSimone/Kobo-Metadata";
    changelog = "https://github.com/NotSimone/Kobo-Metadata/releases/tag/v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
