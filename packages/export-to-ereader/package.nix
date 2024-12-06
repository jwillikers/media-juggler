{
  calibre,
  cbconvert,
  image_optim,
  lib,
  minio-client,
  makeWrapper,
  nushell,
  stdenvNoCC,
  udisks,
  util-linux,
  zip,
}:
if lib.versionOlder nushell.version "0.99" then
  throw "export-to-ereader is not available for Nushell ${nushell.version}"
else
  stdenvNoCC.mkDerivation {
    pname = "export-to-ereader";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = [ makeWrapper ];

    # doCheck = true;

    buildInputs = [
      calibre
      cbconvert
      # comictagger
      # todo comictagger
      # mozjpeg
      image_optim
      minio-client
      nushell
      udisks
      util-linux
      zip
    ];

    # checkPhase = ''
    #   runHook preCheck
    #   nu import-comics-tests.nu
    #   runHook postCheck
    # '';

    installPhase = ''
      runHook preInstall
      install -D --mode=0755 --target-directory=$out/bin export-to-ereader.nu
      wrapProgram $out/bin/export-to-ereader.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            cbconvert
            image_optim
            minio-client
            udisks
            util-linux
            zip
          ]
        }
      runHook postInstall
    '';

    meta.mainProgram = "export-to-ereader.nu";
  }
