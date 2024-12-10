{ pkgs, ... }:
rec {
  beets-audible-config = pkgs.callPackage ./beets-audible-config/package.nix { };
  beetsPlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./beets-plugins { });
  calibrePlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./calibre-plugins { });
  import-comics = pkgs.callPackage ./media-juggler/package.nix { inherit beets-audible-config; };
}
