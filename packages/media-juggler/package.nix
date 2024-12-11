{
  beets-audible-config,
  calibre,
  cbconvert,
  ffmpeg,
  file,
  image_optim,
  lib,
  m4b-tool,
  minio-client,
  makeWrapper,
  nushell,
  stdenvNoCC,
  tone,
  udisks,
  util-linux,
  zip,
}:
if lib.versionOlder nushell.version "0.99" then
  throw "import-comics is not available for Nushell ${nushell.version}"
else
  # let
  # todo Wrap invocations of beets-audible with wrapProgram --add-flags --config + --library
  # deadnix: skip
  # beets-audible = beets.override {
  #   pluginOverrides = {
  #     audible = {
  #       enable = true;
  #       propagatedBuildInputs = [ beetsPlugins.audible ];
  #     };
  #     copyartifacts = {
  #       enable = true;
  #       propagatedBuildInputs = [ beetsPackages.copyartifacts ];
  #     };
  #   };
  # };
  # in
  stdenvNoCC.mkDerivation {
    pname = "import-comics";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = [ makeWrapper ];

    # doCheck = true;

    buildInputs = [
      # beets-audible
      calibre
      cbconvert
      # todo comictagger
      ffmpeg
      file
      # kcc
      image_optim
      m4b-tool
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
      install -D --mode=0755 --target-directory=$out/bin *.nu
      install -D --mode=0644 --target-directory=$out/bin/media-juggler-lib media-juggler-lib/*.nu
      wrapProgram $out/bin/export-to-ereader.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            calibre
            cbconvert
            image_optim
            # kcc
            minio-client
            udisks
            util-linux
            zip
          ]
        }
      wrapProgram $out/bin/import-audiobooks.nu \
        --set BEETSDIR ${beets-audible-config}/etc/beets \
        --prefix PATH : ${
          lib.makeBinPath [
            # beets-audible
            ffmpeg
            image_optim
            m4b-tool
            minio-client
            tone
          ]
        }
      wrapProgram $out/bin/import-comics.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            calibre
            cbconvert
            # comictagger
            image_optim
            # kcc
            minio-client
            udisks
            util-linux
            zip
          ]
        }
      wrapProgram $out/bin/import-ebooks.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            calibre
            file
            image_optim
            minio-client
            udisks
            util-linux
            zip
          ]
        }
      runHook postInstall
    '';
  }
