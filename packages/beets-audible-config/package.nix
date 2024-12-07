{
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "beets-audible-config";
  version = "0";

  src = ./.;

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/etc/beets config.yaml
    install -D --mode=0755 --target-directory=$out/etc/beets/scripts install-deps.sh
    runHook postInstall
  '';

  meta = {
    description = "Config file for the beets-audible plugin";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = with lib.licenses; [ mit ];
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}
