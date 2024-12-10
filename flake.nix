{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs";
      };
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      # deadnix: skip
      self,
      nixpkgs,
      flake-utils,
      pre-commit-hooks,
      treefmt-nix,
    }:
    let
      overlays = import ./overlays { };
      overlaysList = with overlays; [ calibre-acsm-plugin-libcrypto ];
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # pkgs = import nixpkgs { inherit system; }; # overlays = overlaysList; };
        pkgs = import nixpkgs {
          inherit system;
          overlays = overlaysList;
        };
        packages = import ./packages { inherit pkgs; };
        pre-commit = pre-commit-hooks.lib.${system}.run (
          import ./pre-commit-hooks.nix { inherit pkgs treefmtEval; }
        );
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        apps = {
          default = self.apps.${system}.update-nix-direnv;
          update-packages = {
            type = "app";
            program = builtins.toString (
              pkgs.writers.writeNu "update-packages" ''
                ^${pkgs.lib.getExe pkgs.nix-update} calibrePlugins.acsm --build --flake --version branch
                ^${pkgs.lib.getExe pkgs.nix-update} calibrePlugins.comicvine --build --flake
                ^${pkgs.lib.getExe pkgs.nix-update} calibrePlugins.dedrm --build --flake --version branch
                ^${pkgs.lib.getExe pkgs.nix-update} calibrePlugins.embedcomicmetadata --build --flake --version branch
                ^${pkgs.lib.getExe treefmtEval.config.build.wrapper}
              ''
            );
          };
        };
        devShells.default = pkgs.mkShellNoCC {
          inherit (pre-commit) shellHook;
          nativeBuildInputs =
            with pkgs;
            [
              asciidoctor
              fish
              just
              lychee
              nushell
              treefmtEval.config.build.wrapper
              # Make formatters available for IDE's.
              (builtins.attrValues treefmtEval.config.build.programs)
            ]
            ++ pre-commit.enabledPackages;
          inputsFrom = with packages; [
            media-juggler
          ];
        };
        formatter = treefmtEval.config.build.wrapper;
        packages = packages // {
          default = self.packages.${system}.media-juggler;
        };
      }
    )
    // {
      inherit overlays;
      hmModules.media-juggler = import ./home-manager-module.nix self;
      # media-juggler = import ./home-manager-module.nix {};
    };
}
