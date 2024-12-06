_: {
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
