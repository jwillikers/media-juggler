{
  calibre,
  cbconvert,
  image_optim,
  lib,
  minio-client,
  nushell,
  stdenvNoCC,
  udisks,
  util-linux,
  zip,
}:
if lib.versionOlder nushell.version "0.99" then
  throw "media-juggler-lib is not available for Nushell ${nushell.version}"
else
  stdenvNoCC.mkDerivation {
    pname = "media-juggler-lib";
    version = "0.1.0";

    src = ./.;

    # todo How to propagate required utilities?

    # doCheck = true;

    buildInputs = [
      calibre
      cbconvert
      # todo comictagger
      image_optim
      minio-client
      nushell
      udisks
      util-linux
      zip
    ];

    # checkPhase = ''
    #   runHook preCheck
    #   nu media-juggler-tests.nu
    #   runHook postCheck
    # '';

    installPhase = ''
      runHook preInstall
      install -D --mode=0644 --target-directory=$out/share/media-juggler *.nu
      runHook postInstall
    '';
  }
