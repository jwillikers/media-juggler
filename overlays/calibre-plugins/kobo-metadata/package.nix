{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
  zip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "kobo-metadata";
  version = "1.12.1";

  src = fetchFromGitHub {
    owner = "NotSimone";
    repo = "Kobo-Metadata";
    rev = "refs/tags/${version}";
    hash = "sha256-zRD6A8b5pZRyOwCoagI+4CdUUhpidWNu7zqBIYSf38I=";
  };

  nativeBuildInputs = [ zip ];

  buildPhase = ''
    runHook preBuild
    ${lib.getExe zip} --recurse-paths KoboMetadata *
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins KoboMetadata.zip
    runHook postInstall
  '';

  meta = {
    description = "Fetch metadata for Calibre from Kobo";
    homepage = "https://github.com/NotSimone/Kobo-Metadata";
    changelog = "https://github.com/NotSimone/Kobo-Metadata/releases/tag/v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
