{
  description = "Flk Devshell - a user friendly devshell for devos";

  inputs.nixpkgs.url = "nixpkgs";
  inputs.devshell.url = "github:numtide/devshell";
  inputs.flk.url = "path:../flk/";
  inputs.flk.inputs.nixpkgs.follows = "nixpkgs";
  inputs.deploy.url = "github:serokell/deploy-rs";
  inputs.deploy.inputs.nixpkgs.follows = "nixpkgs";
  inputs.deploy.inputs.utils.follows = "utils";
  inputs.utils.url = "github:gytis-ivaskevicius/flake-utils-plus/staging";

  outputs = { self, nixpkgs, devshell, deploy, flk, ... }: let

    # Unofficial Flakes Roadmap - Polyfills
    # .. see: https://demo.hedgedoc.org/s/_W6Ve03GK#
    # .. also: <repo-root>/ufr-polyfills

    # Super Stupid Flakes / System As an Input - Style:
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin"];
    ufrContract = import ../ufr-polyfills/ufrContract.nix;

    # Dependency Groups - Style
    flkShellInputs = { inherit self nixpkgs devshell flk; };

    # repind this flake's functor to new self as part of the inputs
    # this helps to completely avoid invoking flake.lock.nix.
    # In a flake-only scenario, flake.lock.nix would disregard
    # inputs follows configurations.
    rebind = src: inpt: _: args: rebound:
      let
        inputs = inpt // { self = rebound; };
      in
      import src ({ inherit inputs; } // args);

    # .. we hope you like this style.
    # .. it's adopted by a growing number of projects.
    # Please consider adopting it if you want to help to improve flakes.

  in
  {

    overlays = {
      enable-deploy = deploy.overlay;
      patched-nix = import ../patchedNix;
    };

    devShell = ufrContract supportedSystems ./. flkShellInputs;

    # usage:
    # inputs.flk-shell.inputs = {
    #   nixpkgs.follows = "";
    #   # this does not (yet) work -- hence rebind workaround
    #   self.follows = "self"; # bind to new self
    #   devshell.follows = ""; optional
    # };
    #
    # then: # flk-shell { ... } newSelf;
    # 
    functor = rebind ./. flkShellInputs;

  };
}
