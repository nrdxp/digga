{
  description = "Flk Devshell - a user friendly devshell for devos";

  inputs = {
    nixpkgs.url = "nixpkgs";
    devshell.url = "github:numtide/devshell";
    deploy = {
      url = "github:serokell/deploy-rs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        utils.follows = "utils";
      };
    };
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus/staging";
  };

  outputs = { self, nixpkgs, devshell, deploy, ... }: let

    # Unofficial Flakes Roadmap - Polyfills
    # .. see: https://demo.hedgedoc.org/s/_W6Ve03GK#
    # .. also: <repo-root>/ufr-polyfills

    # Super Stupid Flakes / System As an Input - Style:
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin"];
    ufrContractCalled = import ../ufr-polyfills/ufrContractCalled.nix;

    # Dependency Groups - Style
    flkShellInputs = { inherit self nixpkgs devshell; };

    # .. we hope you like this style.
    # .. it's adopted by a growing number of projects.
    # Please consider adopting it if you want to help to improve flakes.

  in
  {

    overlays = {
      enable-deploy = deploy.overlay;
      patched-nix = import ../patchedNix;
    };

    flkShell = import ./. { inputs = { inherit flkShellInputs; }; };

    devShell = ufrContractCalled supportedSystems ./. flkShellInputs { };

  };
}
