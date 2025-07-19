{ pkgs, ... }:
{
  calibrePlugins = pkgs.recurseIntoAttrs (pkgs.callPackages ./calibre-plugins { });
  media-juggler = pkgs.callPackage ./media-juggler/package.nix { };
}
