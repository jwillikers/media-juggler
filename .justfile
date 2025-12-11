default: build

alias b := build

build derivation="update-nix-direnv":
    nix build ".#{{ derivation }}"

alias c := check

check: && format
    yamllint .
    asciidoctor **/*.adoc
    lychee --cache **/*.html
    nix flake check

alias f := format
alias fmt := format

format:
    treefmt

alias r := run

run derivation="update-nix-direnv":
    nix run ".#{{ derivation }}"

alias t := test

test:
    nu overlays/media-juggler/media-juggler-lib-tests.nu
    nu overlays/media-juggler/import-music-tests.nu

alias u := update
alias up := update

update:
    nix run ".#update-nix-direnv"
    nix run ".#update-nixos-release"
    nix flake update
