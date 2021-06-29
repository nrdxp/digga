{
  description = "Flk - a highly composable system ctl command";

  inputs = {
    nixpkgs.url = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }: let

    # Unofficial Flakes Roadmap - Polyfills
    # .. see: https://demo.hedgedoc.org/s/_W6Ve03GK#
    # .. also: <repo-root>/ufr-polyfills

    # Super Stupid Flakes / System As an Input - Style:
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin"];
    ufrContract = import ../ufr-polyfills/ufrContract.nix;

    # Dependency Groups - Style
    flkInputs = { inherit self nixpkgs; };

    # .. we hope you like this style.
    # .. it's adopted by a growing number of projects.
    # Please consider adopting it if you want to help to improve flakes.

  in
  {

    overlays = {
      patched-nix = import ../patchedNix;
    };

    flkModules = {
      disable-repl = { flk.cmds.repl.enable = false; }; # it's not yet working
    };

    flk = import ./. { inputs = { inherit flkInputs; }; };

    defaultPackage = ufrContract supportedSystems ./. flkInputs;

  };
}
