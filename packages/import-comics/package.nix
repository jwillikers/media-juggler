{
  calibre,
  cbconvert,
  image_optim,
  lib,
  minio-client,
  makeWrapper,
  nushell,
  stdenvNoCC,
  zip,
}:
if lib.versionOlder nushell.version "0.99" then
  throw "import-comics is not available for Nushell ${nushell.version}"
else
  stdenvNoCC.mkDerivation {
    pname = "import-comics";
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
      zip
    ];

    # checkPhase = ''
    #   runHook preCheck
    #   nu import-comics-tests.nu
    #   runHook postCheck
    # '';

    installPhase = ''
      runHook preInstall
      install -D --mode=0755 --target-directory=$out/bin import-comics.nu
      wrapProgram $out/bin/import-comics.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            calibre
            cbconvert
            # comictagger
            image_optim
            minio-client
            zip
          ]
        }
      runHook postInstall
    '';

    meta.mainProgram = "import-comics.nu";
  }
