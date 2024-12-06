{ pkgs, ... }:
{
  audible = pkgs.callPackage ./audible/package.nix { };
}
