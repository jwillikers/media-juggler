{ pkgs, ... }:
{
  calibrePlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./calibre-plugins { });
  import-comics = pkgs.callPackage ./media-juggler/package.nix { };
}
