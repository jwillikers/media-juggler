{
  # beets,
  calibre,
  cbconvert,
  chromaprint,
  ffmpeg,
  file,
  image_optim,
  keyfinder-cli,
  lib,
  # m4b-tool,
  minio-client,
  makeWrapper,
  mupdf-headless,
  nushell,
  picard,
  stdenvNoCC,
  tesseract,
  tone,
  udisks,
  unstable,
  util-linux,
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

    doCheck = true;

    buildInputs = [
      unstable.beets
      calibre
      cbconvert
      # todo comictagger
      ffmpeg
      file
      # kcc
      image_optim
      keyfinder-cli
      # m4b-tool
      minio-client
      nushell
      picard
      tesseract
      udisks
      util-linux
      zip
    ];

    checkPhase = ''
      runHook preCheck
      nu import-music-tests.nu
      runHook postCheck
    '';

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
        --prefix PATH : ${
          lib.makeBinPath [
            chromaprint
            ffmpeg
            image_optim
            # m4b-tool
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
            mupdf-headless
            tesseract
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
            mupdf-headless
            tesseract
            udisks
            util-linux
            zip
          ]
        }
      wrapProgram $out/bin/import-music.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            unstable.beets
            image_optim
            keyfinder-cli
            minio-client
            picard # For mbsubmit Beets plugin
          ]
        }
      runHook postInstall
    '';
  }
