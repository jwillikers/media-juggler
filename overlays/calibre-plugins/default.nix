{ pkgs, ... }:
{
  acsm = pkgs.callPackage ./acsm/package.nix { };
  comicvine = pkgs.callPackage ./comicvine/package.nix { };
  embedcomicmetadata = pkgs.callPackage ./embedcomicmetadata/package.nix { };
  extract_isbn = pkgs.callPackage ./extract_isbn/package.nix { };
  goodreads = pkgs.callPackage ./goodreads/package.nix { };
  # https://github.com/RobBrazier/calibre-plugins
  # todo hardcover = pkgs.callPackage ./hardcover/package.nix { };
  # todo kfx-input = pkgs.callPackage ./kfx-input/package.nix { };
  # todo Barnes & Noble plugin: https://www.mobileread.com/forums/showthread.php?t=132508
  kobo-metadata = pkgs.callPackage ./kobo-metadata/package.nix { };
  modify_epub = pkgs.callPackage ./modify_epub/package.nix { };
  # todo? https://github.com/un-pogaz/ePub-Extended-Metadata
  # todo? https://github.com/akupiec/calibre_plugin_audiobook-metadata
  # todo? https://github.com/kiwidude68/calibre_plugins/wiki/Quality-Check
}
