{ system ? builtins.currentSystem
, inputs ? import ../ufr-polyfills/flake.lock.nix ./.

# alternative 1 --------------------------------------------------

, pkgs ? import inputs.nixpkgs {
    inherit system;
    overlays = inputs.nixpkgs.lib.optionals
      ((builtins.hasAttr "self" inputs) && (builtins.hasAttr "overlays" inputs.self))
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
      ((builtins.hasAttr "self" inputs) && (builtins.hasAttr "devshellModules" inputs.self))
      (builtins.attrValues inputs.self.devshellModules)
}:
let

  flk = pkgs.callPackage ./flk { };
  ssh-show = pkgs.callPackage ./ssh-show { };
  hooks = import ./hooks;

  withCategory = category: attrset: attrset // { inherit category; };
  linter = withCategory "linter";
  docs = withCategory "docs";
  devos = withCategory "devos";

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
    (devos { package = flk; })
    (devos { package = ssh-show; })
    (devos { package = nixFlakes; })
    (linter { package = nixpkgs-fmt; })
    (linter { package = editorconfig-checker; })
    # (docs { package = python3Packages.grip; }) too many deps
    (docs { package = mdbook; })
  ]

  ++ lib.optional
    (builtins.hasAttr "deploy-rs" pkgs)
    (devos { package = deploy-rs.deploy-rs; })

  ++ lib.optional
    (builtins.hasAttr "fup-repl" pkgs)
    (devos { package = fup-repl; })

  ++ lib.optional
    (system != "i686-linux")
    (devos { package = cachix; })

  ;
}
