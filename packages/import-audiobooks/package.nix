{
  lib,
  beets,
  beetsPackages,
  beetsPlugins,
  image_optim,
  media-juggler-lib,
  minio-client,
  makeWrapper,
  nushell,
  stdenvNoCC,
  tone,
}:
if lib.versionOlder nushell.version "0.99" then
  throw "import-audiobooks is not available for Nushell ${nushell.version}"
else
  let
    # todo Wrap invocations of beets-audible with wrapProgram --add-flags --config + --library
    # deadnix: skip
    beets-audible = beets.override {
      pluginOverrides = {
        audible = {
          enable = true;
          propagatedBuildInputs = [ beetsPlugins.audible ];
        };
        copyartifacts = {
          enable = true;
          propagatedBuildInputs = [ beetsPackages.copyartifacts ];
        };
      };
    };
  in
  stdenvNoCC.mkDerivation {
    pname = "import-audiobooks";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = [ makeWrapper ];

    buildInputs = [
      # beets-audible
      image_optim
      minio-client
      nushell
      tone
    ];

    # Always pass --config to beets?
    installPhase = ''
      runHook preInstall
      install -D --mode=0755 --target-directory=$out/bin import-audiobooks.nu
      wrapProgram $out/bin/import-audiobooks.nu \
        --prefix NU_LIB_DIRS : ${media-juggler-lib}/share \
        --prefix PATH : ${
          lib.makeBinPath [
            # beets-audible
            image_optim
            minio-client
            tone
          ]
        }
      runHook postInstall
    '';

    meta.mainProgram = "import-audiobooks.nu";
  }
