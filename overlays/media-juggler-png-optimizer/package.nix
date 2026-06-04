{
  efficient-compression-tool,
  lib,
  makeWrapper,
  nushell,
  oxipng,
  pngcrush,
  stdenvNoCC,
}:
if lib.versionOlder nushell.version "0.99" then
  throw "media-juggler-png-optimizer is not available for Nushell ${nushell.version}"
else
  stdenvNoCC.mkDerivation {
    pname = "media-juggler-png-optimizer";
    version = "0.0.1";

    src = ./.;

    nativeBuildInputs = [ makeWrapper ];

    doCheck = true;

    buildInputs = [
      efficient-compression-tool
      nushell
      oxipng
      pngcrush
    ];

    installPhase = ''
      runHook preInstall
      install -D --mode=0755 --target-directory=$out/bin *.nu
      wrapProgram $out/bin/media-juggler-png-optimizer.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            efficient-compression-tool
            oxipng
            pngcrush
          ]
        }
      runHook postInstall
    '';

    meta = {
      mainProgram = "media-juggler-png-optimizer.nu";
    };
  }
