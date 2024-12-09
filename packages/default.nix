{ pkgs, ... }:
rec {
  beetsPlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./beets-plugins { });
  calibrePlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./calibre-plugins { });
  export-to-ereader = pkgs.callPackage ./export-to-ereader/package.nix { inherit media-juggler-lib; };
  import-audiobooks = pkgs.callPackage ./import-audiobooks/package.nix {
    inherit beetsPlugins media-juggler-lib;
  };
  import-comics = pkgs.callPackage ./import-comics/package.nix { inherit media-juggler-lib; };
  media-juggler-lib = pkgs.callPackage ./media-juggler-lib/package.nix { };
}
