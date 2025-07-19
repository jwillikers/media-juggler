{
  fetchFromGitHub,
  lib,
  openssl_legacy,
  pkgsCross,
  python3,
  python3Packages,
  stdenv,
  stdenvNoCC,
  zip,
}:
let
  oscrypto = python3Packages.oscrypto.overrideAttrs (_prevAttrs: {
    # It's necessary to use cryptographic protocols from openssl_legacy in order to communicate with the ADE server.
    # OSError: OpenSSL has been compiled without RC2 support
    postPatch = ''
      for file in oscrypto/_openssl/_lib{crypto,ssl}_c{ffi,types}.py; do
        substituteInPlace $file \
          --replace "get_library('crypto', 'libcrypto.dylib', '42')" "'${openssl_legacy.out}/lib/libcrypto${stdenv.hostPlatform.extensions.sharedLibrary}'" \
          --replace "get_library('ssl', 'libssl', '44')" "'${openssl_legacy.out}/lib/libssl${stdenv.hostPlatform.extensions.sharedLibrary}'"
      done
    '';
  });
in
stdenvNoCC.mkDerivation rec {
  pname = "acsm";
  version = "0.0.16-unstable-2024-09-17";

  src = fetchFromGitHub {
    owner = "Leseratte10";
    repo = "acsm-calibre-plugin";
    rev = "2f40289a847bdd1cc8aac5284fd74d0ee03cd3b8";
    hash = "sha256-ds1qm9vN9D8NGspseBgqP3tujtKJB7ivFyfS3mlFDB8=";
  };

  # asn1cryptoSrc = fetchurl {
  #   url = "https://github.com/Leseratte10/acsm-calibre-plugin/releases/download/config/asn1crypto_1.5.1.zip";
  #   hash = "sha256-f0Wtf5qLAtuPqQ80uOfWtV4grf5CChRL3fcjkMSmEFA=";
  # };

  # oscryptoSrc = fetchurl {
  #   url = "https://github.com/Leseratte10/acsm-calibre-plugin/releases/download/config/oscrypto_1.3.0_fork_2023-12-19.zip";
  #   hash = "sha256-D872/kQemxB2D7yUSuCIreAMGJOc9V7PtVommZPlwxc=";
  # };

  nativeBuildInputs = [
    pkgsCross.mingw32.buildPackages.gcc
    pkgsCross.mingwW64.buildPackages.gcc
    zip
  ];

  propagatedBuildInputs = [
    python3Packages.asn1crypto
    oscrypto
  ];

  # cp ${asn1cryptoSrc} calibre-plugin/asn1crypto.zip
  # cp ${oscryptoSrc} calibre-plugin/oscrypto.zip
  buildPhase = ''
    runHook preBuild
    mkdir -p calibre-plugin/{asn1crypto,oscrypto}
    ln --symbolic ${python3Packages.asn1crypto}/lib/python${python3.pythonVersion}/site-packages/asn1crypto calibre-plugin/asn1crypto/asn1crypto
    ln --symbolic ${oscrypto}/lib/python${python3.pythonVersion}/site-packages/oscrypto calibre-plugin/oscrypto/oscrypto

    cd calibre-plugin/
    ${lib.getExe zip} --recurse-paths asn1crypto asn1crypto
    ${lib.getExe zip} --recurse-paths oscrypto oscrypto
    rm -rf asn1crypto oscrypto
    cd -

    bash ./bundle_calibre_plugin.sh
    bash ./bundle_migration_plugin.sh
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins calibre-plugin.zip calibre-migration-plugin.zip
    runHook postInstall
  '';

  meta = {
    description = "Calibre plugin for ACSM->EPUB and ACSM->PDF conversion";
    homepage = "https://www.mobileread.com/forums/showthread.php?t=341975";
    changelog = "https://github.com/Leseratte10/acsm-calibre-plugin/releases/tag/v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = with lib.licenses; [ gpl3Only ];
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
