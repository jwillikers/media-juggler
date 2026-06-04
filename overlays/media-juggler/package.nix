{
  advancecomp,
  b3sum,
  beets,
  calibre,
  chromaprint,
  efficient-compression-tool,
  exiftool,
  ffmpeg,
  file,
  image_optim,
  imagemagick,
  isbntools,
  keyfinder-cli,
  lib,
  m4b-tool,
  makeWrapper,
  media-juggler-png-optimizer,
  minuimus,
  mupdf-headless,
  nushell,
  picard,
  rhash,
  rsync,
  stdenvNoCC,
  tesseract,
  tone,
  udisks,
  util-linux,
  zip,
}:
if lib.versionOlder nushell.version "0.99" then
  throw "media-juggler is not available for Nushell ${nushell.version}"
else
  stdenvNoCC.mkDerivation {
    pname = "media-juggler";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = [ makeWrapper ];

    doCheck = true;

    buildInputs = [
      beets
      advancecomp
      calibre
      efficient-compression-tool
      ffmpeg
      file
      image_optim
      isbntools
      # kcc
      keyfinder-cli
      m4b-tool
      media-juggler-png-optimizer
      minuimus
      nushell
      picard
      rsync
      tesseract
      udisks
      util-linux
      zip
    ];

    checkPhase = ''
      runHook preCheck
      nu media-juggler-lib-tests.nu
      nu import-comics-tests.nu
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
            advancecomp
            calibre
            efficient-compression-tool
            image_optim
            media-juggler-png-optimizer
            minuimus
            udisks
            util-linux
            zip
          ]
        }
      wrapProgram $out/bin/import-audiobooks.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            chromaprint
            b3sum
            efficient-compression-tool
            ffmpeg
            image_optim
            isbntools
            media-juggler-png-optimizer
            minuimus
            m4b-tool
            rhash
            rsync
            tone
            zip
          ]
        }
      wrapProgram $out/bin/import-comics.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            advancecomp
            b3sum
            calibre
            efficient-compression-tool
            exiftool
            image_optim
            media-juggler-png-optimizer
            imagemagick
            # kcc
            minuimus
            mupdf-headless
            rhash
            rsync
            tesseract
            udisks
            util-linux
            zip
          ]
        }
      wrapProgram $out/bin/import-ebooks.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            advancecomp
            calibre
            efficient-compression-tool
            file
            image_optim
            isbntools
            media-juggler-png-optimizer
            minuimus
            mupdf-headless
            rsync
            tesseract
            udisks
            util-linux
            zip
          ]
        }
      wrapProgram $out/bin/import-music.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            # todo optimize flacs like minuimus does?
            beets
            efficient-compression-tool
            image_optim
            # jpegli
            media-juggler-png-optimizer
            rsync
            keyfinder-cli
            picard # For mbsubmit Beets plugin
          ]
        }
      runHook postInstall
    '';
  }
