{
  stdenv,
  lib,
  advancecomp,
  brotli,
  bzip2,
  cabextract,
  coreutils, # for sha256sum
  fetchzip,
  ffmpeg-headless,
  file,
  flac,
  flexigif,
  gif2apng,
  gifsicle,
  gnutar,
  gzip,
  image_optim,
  imagemagick,
  imgdataopt,
  jbig2enc,
  jbig2dec,
  jpeg2png,
  jpegoptim,
  # todo knusperli, https://github.com/google/knusperli
  leanify,
  libjpeg,
  libtiff,
  libwebp,
  lzip,
  makeWrapper,
  mupdf-headless,
  nix-update-script,
  optipng,
  p7zip,
  pdfsizeopt,
  perl,
  tif22pnm,
  withPngout ? false,
  pngout, # disabled by default because it's unfree
  poppler-utils,
  qpdf,
  rzip,
  sam2p,
  unrar-free,
  versionCheckHook,
  which,
  zip,
  zlib,
  zopfli,
  zpaq,
}:
stdenv.mkDerivation {
  pname = "minuimus";
  version = "4.1";

  src = fetchzip {
    url = "https://birds-are-nice.me/software/minuimus.zip";
    hash = "sha256-QRi1JgIQzhn4ojkZ9rDpQg76MA+FgNFtPusCzDhewZ4=";
    stripRoot = false;
  };

  patches = [ ./image_optim.patch ];

  postPatch = ''
    rm zopfli/*.c
    substituteInPlace minuimus.pl \
      --replace-fail "my \$im_identify='identify-im6';" "my \$im_identify='magick';" \
      --replace-fail "my \$im_convert='convert-im6';" "my \$im_convert='magick';" \
      --replace-fail "my \$im_mode=0;" "my \$im_mode=1;"
    for program in "cab_analyze" "minuimus_def_helper" "minuimus_woff_helper"; do
      substituteInPlace minuimus.pl \
        --replace-fail "/usr/bin/$program" "${placeholder "out"}/bin/$program"
    done
    substituteInPlace makefile \
      --replace-fail "i686-w64-mingw32-gcc" "${stdenv.cc.targetPrefix}cc" \
      --replace-fail "gcc" "${stdenv.cc.targetPrefix}cc" \
      --replace-fail "zopfli/deflate.c zopfli/lz77.c zopfli/hash.c zopfli/tree.c zopfli/squeeze.c zopfli/blocksplitter.c  zopfli/cache.c zopfli/katajainen.c zopfli/util.c zopfli/zlib_container.c -lm" "-lzopfli" \
      --replace-fail "zopfli/deflate.c zopfli/lz77.c zopfli/hash.c zopfli/tree.c zopfli/squeeze.c zopfli/blocksplitter.c zopfli/cache.c zopfli/katajainen.c zopfli/util.c zopfli/zlib_container.c -lm" "-lzopfli"
  '';

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    perl
    zlib
    zopfli
  ];

  buildFlags = lib.optionals stdenv.hostPlatform.isWindows [ "windows" ];

  installPhase = ''
    runHook preInstall
    install -Dm0755 --target-directory $out/bin \
      minuimus_def_helper \
      minuimus_woff_helper \
      cab_analyze \
      minuimus.pl \
      minuimus_swf_helper
    wrapProgram $out/bin/minuimus.pl \
      --set PERL5LIB $PERL5LIB \
      --prefix PATH : $out/bin \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            advancecomp
            brotli
            bzip2
            cabextract
            file
            flac
            ffmpeg-headless
            flexigif
            gif2apng
            gifsicle
            gnutar
            gzip
            image_optim
            imagemagick
            imgdataopt
            jbig2enc
            jbig2dec
            jpeg2png
            jpegoptim
            # todo knusperli
            leanify
            libjpeg
            libtiff
            libwebp
            lzip
            mupdf-headless
            optipng
            p7zip
            pdfsizeopt
            poppler-utils
            tif22pnm # Not used directly, but existence is verified in minuimus.pl for pdfsizeopt
            pngout
            qpdf
            rzip
            sam2p # Not used directly, but existence is verified in minuimus.pl for pdfsizeopt
            unrar-free
            zip
            zpaq
          ]
          ++ lib.optionals withPngout [
            pngout
          ]
          ++ lib.optionals stdenv.hostPlatform.isUnix [
            coreutils # sha256sum
            which
          ]
        )
      }
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/minuimus.pl";

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "A file optimiser utility script: You point it at a file, and it makes the file smaller without compromising the file contents.";
    homepage = "https://birds-are-nice.me/software/minuimus.html";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
    maintainers = with lib.maintainers; [ jwillikers ];
    mainProgram = "minuimus.pl";
  };
}
