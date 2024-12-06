{ pkgs, ... }:
rec {
  beetsPlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./beets-plugins { });
  calibrePlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./calibre-plugins { });
  export-to-ereader = pkgs.callPackage ./export-to-ereader/package.nix { };
  import-audiobooks = pkgs.callPackage ./import-audiobooks/package.nix { inherit beetsPlugins; };
  import-comics = pkgs.callPackage ./import-comics/package.nix { };
}
