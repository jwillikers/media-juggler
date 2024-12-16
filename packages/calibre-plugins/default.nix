{ pkgs, ... }:
{
  acsm = pkgs.callPackage ./acsm/package.nix { };
  comicvine = pkgs.callPackage ./comicvine/package.nix { };
  dedrm = pkgs.callPackage ./dedrm/package.nix { };
  embedcomicmetadata = pkgs.callPackage ./embedcomicmetadata/package.nix { };
  extract_isbn = pkgs.callPackage ./extract_isbn/package.nix { };
  goodreads = pkgs.callPackage ./goodreads/package.nix { };
  kobo-metadata = pkgs.callPackage ./kobo-metadata/package.nix { };
  modify_epub = pkgs.callPackage ./modify_epub/package.nix { };
  # todo? https://github.com/un-pogaz/ePub-Extended-Metadata
  # todo? https://github.com/akupiec/calibre_plugin_audiobook-metadata
  # todo? https://github.com/kiwidude68/calibre_plugins/wiki/Quality-Check
}
