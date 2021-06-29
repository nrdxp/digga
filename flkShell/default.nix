{ system ? builtins.currentSystem
, inputs ? import ../ufr-polyfills/flake.lock.nix ./.

# alternative 1 --------------------------------------------------

, pkgs ? import inputs.nixpkgs {
    inherit system;
    overlays = inputs.nixpkgs.lib.optionals
      ((inputs ? self) && (inputs.self ? overlays))
      (builtins.attrValues inputs.self.overlays)
    ;
    config = { };
  }

# alternative 2 --------------------------------------------------

, devshell ? import inputs.devshell { inherit pkgs; }

# ----------------------------------------------------------------
}:

{
  channelName ? "no-channel"
, devshellModules ? pkgs.lib.optionals
      ((inputs ? self) && (inputs.self ? devshellModules))
      (builtins.attrValues inputs.self.devshellModules)
}:
let

  flk = pkgs.callPackage ./flk { };
  ssh-show = pkgs.callPackage ./ssh-show { };
  hooks = import ./hooks;

  pkgWithCategory = category: pkg: { package = pkg; inherit category; };
  linter = pkgWithCategory "linter";
  docs = pkgWithCategory "docs";
  devos = pkgWithCategory "devos";

  installPkgs = (import "${toString pkgs.path}/nixos/lib/eval-config.nix" {
    inherit (pkgs) system;
    modules = [ ];
  }).config.system.build;

in

devshell.mkShell {

  imports = [ "${devshell.extraModulesDir}/git/hooks.nix" ] ++ devshellModules;
  git = { inherit hooks; };

  name = "flk-${channelName}";

  # tempfix: remove when merged https://github.com/numtide/devshell/pull/123
  devshell.startup.load_profiles = pkgs.lib.mkForce (pkgs.lib.noDepEntry ''
    # PATH is devshell's exorbitant privilige:
    # fence against its pollution
    _PATH=''${PATH}
    # Load installed profiles
    for file in "$DEVSHELL_DIR/etc/profile.d/"*.sh; do
      # If that folder doesn't exist, bash loves to return the whole glob
      [[ -f "$file" ]] && source "$file"
    done
    # Exert exorbitant privilige and leave no trace
    export PATH=''${_PATH}
    unset _PATH
  '');

  packages = with installPkgs; [
    installPkgs.nixos-install
    installPkgs.nixos-generate-config
    installPkgs.nixos-enter
    pkgs.git-crypt
    pkgs.nixos-rebuild
  ];

  commands = with pkgs; [
    (devos flk)
    (devos ssh-show)
    (devos nixDiggaPatched)
    (linter nixpkgs-fmt)
    (linter editorconfig-checker)
    # (docs python3Packages.grip) too many deps
    (docs mdbook)
  ]

  ++ lib.optional
    (pkgs ? deploy-rs)
    (devos deploy-rs.deploy-rs)

  ++ lib.optional
    (pkgs ? fup-repl)
    (devos fup-repl)

  ++ lib.optional
    (system != "i686-linux")
    (devos cachix)

  ;
}