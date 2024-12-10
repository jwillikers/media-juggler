{ pkgs, ... }:
{
  beetsPlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./beets-plugins { });
  calibrePlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./calibre-plugins { });
  import-comics = pkgs.callPackage ./media-juggler/package.nix { };
}
