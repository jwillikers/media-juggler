{ pkgs, ... }:
rec {
  beetsPlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./beets-plugins { });
  calibrePlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./calibre-plugins { });
  import-audiobooks = pkgs.callPackage ./import-audiobooks/package.nix { inherit beetsPlugins; };
  import-comics = pkgs.callPackage ./import-comics/package.nix { };
}
