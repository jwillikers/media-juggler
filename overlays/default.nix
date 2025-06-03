{ inputs }:
{
  unstablePackages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable { inherit (final) system; };
  };
  image_optim = _final: prev: {
    image_optim = prev.image_optim.override { withPngout = true; };
  };
  efficient-compression-tool = _final: prev: {
    efficient-compression-tool = prev.callPackage ./efficient-compression-tool/package.nix { };
  };
  jpegli = _final: prev: {
    jpegli = prev.callPackage ./jpegli/package.nix { };
  };
  m4b-tool = inputs.m4b-tool.overlay;
  calibre-acsm-plugin-libcrypto = _final: _prev: {
    # calibre = prev.calibre.overrideAttrs (prevAttrs:
    # let
    #   openssl = prev.calibre.overrideAttrs (prevAttrs:
    #   );
    # in
    # {
    #   buildInputs = prevAttrs.buildInputs ++ [ final.openssl_legacy ];
    #   preFixup = (
    #     builtins.replaceStrings
    #       [
    #         ''
    #           ''${gappsWrapperArgs[@]} \
    #         ''
    #       ]
    #       [
    #         ''
    #           ''${gappsWrapperArgs[@]} \
    #           --set ACSM_LIBCRYPTO ${final.openssl_legacy.out}/lib/libcrypto.so \
    #           --set ACSM_LIBSSL ${final.openssl_legacy.out}/lib/libssl.so \
    #         ''
    #       ]
    #       prevAttrs.preFixup
    #   );
    # });
  };
}
