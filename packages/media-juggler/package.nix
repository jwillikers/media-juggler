{
  advancecomp,
  # beets,
  calibre,
  cbconvert,
  chromaprint,
  efficient-compression-tool,
  ffmpeg,
  file,
  image_optim,
  jpegli,
  keyfinder-cli,
  lib,
  m4b-tool,
  makeWrapper,
  minuimus,
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
      advancecomp
      calibre
      cbconvert
      # todo comictagger
      efficient-compression-tool
      ffmpeg
      file
      # kcc
      image_optim
      keyfinder-cli
      m4b-tool
      minuimus
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
            advancecomp
            calibre
            cbconvert
            efficient-compression-tool
            image_optim
            jpegli
            minuimus
            # kcc
            udisks
            util-linux
            zip
          ]
        }
      wrapProgram $out/bin/import-audiobooks.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            chromaprint
            efficient-compression-tool
            ffmpeg
            image_optim
            jpegli
            minuimus
            m4b-tool
            tone
            zip
          ]
        }
      wrapProgram $out/bin/import-comics.nu \
        --prefix PATH : ${
          lib.makeBinPath [
            advancecomp
            calibre
            cbconvert
            # comictagger
            efficient-compression-tool
            image_optim
            jpegli
            # kcc
            minuimus
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
            advancecomp
            calibre
            efficient-compression-tool
            file
            image_optim
            jpegli
            minuimus
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
            # todo optimize flacs like minuimus does?
            unstable.beets
            efficient-compression-tool
            image_optim
            jpegli
            keyfinder-cli
            picard # For mbsubmit Beets plugin
          ]
        }
      runHook postInstall
    '';
  }
