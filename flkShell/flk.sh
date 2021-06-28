#!/usr/bin/env bash

[[ -d "$DEVSHELL_ROOT" ]] ||
  {
    echo "This script must be run from devos's devshell" >&2
    exit 1
  }

shopt -s extglob

HOSTNAME="$(hostname)"

usage () {
  printf "%b\n" \
    "\e[4mUsage\e[0m: $(basename $0) COMMAND [ARGS]\n" \
    "\e[4mCommands\e[0m:"

  printf "  %-30s %s\n\n" \
  "up" "Generate $DEVSHELL_ROOT/hosts/up-$HOSTNAME.nix" \
  "update [INPUT]" "Update and commit the lock file, or specific input" \
  "get (core|community) [DEST]" "Copy the desired template to DEST" \
  "build HOST BUILD" "Build a variant of your configuration from system.build"
  "vm HOST" "Generate a vm for HOST" \
  "vm run HOST" "run a one-shot vm for HOST" \
  "install HOST [ARGS]" "Shortcut for nixos-install" \
  "home HOST USER [switch]" "Home-manager config of USER from HOST" \
  "HOST (switch|boot|test)" "Shortcut for nixos-rebuild" \
  "repl FLAKE" "Enter a repl with the flake's outputs"
}

case "$1" in
  ""|"-h"|"help"|*(-)"help")
    usage
    ;;

  "up")
    mkdir -p "$DEVSHELL_ROOT/up"

    # `sudo` is necessary for `btrfs subvolume show`
    sudo nixos-generate-config --dir "$DEVSHELL_ROOT/up/$HOSTNAME"

    printf "%s\n" \
      "{ suites, ... }:" \
      "{" \
      "  imports = [" \
      "    ../up/$HOSTNAME/configuration.nix" \
      "  ] ++ suites.core;" \
      "}" > "$DEVSHELL_ROOT/hosts/up-$HOSTNAME.nix"

    git add -f \
      "$DEVSHELL_ROOT/up/$HOSTNAME" \
      "$DEVSHELL_ROOT/hosts/up-$HOSTNAME.nix"
    ;;

  "update")
    if [[ -n "$2" ]]; then
      if [[ -n "$3" ]]; then
        (cd $2; nix flake lock --update-input "$3")
      else
        (cd $2; nix flake update)
      fi
      nix flake lock --update-input "$2" "$DEVSHELL_ROOT"
    else
      nix flake update "$DEVSHELL_ROOT"
    fi
    ;;

  "get")
    if [[ "$2" == "core" || "$2" == "community" ]]; then
      nix flake new -t "github:divnix/devos/$2" "${3:-flk}"
    else
      echo "flk get (core|community) [DEST]"
      exit 1
    fi
    ;;

  "build")
    nix build \
      "$DEVSHELL_ROOT#nixosConfigurations.$2.config.system.build.$3" \
      "${@:4}"
    ;;

  "vm")
    if [[ "$2" == "run" ]]; then
      rm -rf "$DEVSHELL_ROOT/vm/tmp/$3"* \
      && nix build \
        "$DEVSHELL_ROOT#nixosConfigurations.$3.config.system.build.vm" \
        -o "$DEVSHELL_ROOT/vm/tmp/$3" \
        "${@:4}" \
      && \
      ( \
        export NIX_DISK_IMAGE="$DEVSHELL_ROOT/vm/tmp/$3.qcow2" \
        && "$DEVSHELL_ROOT/vm/tmp/$3/bin/run-$3-vm" \
      ) \
      && rm -rf "$DEVSHELL_ROOT/vm/tmp/$3"* \
      && rmdir --ignore-fail-on-non-empty "$DEVSHELL_ROOT/vm/tmp"
    else
      nix build \
        "$DEVSHELL_ROOT#nixosConfigurations.$2.config.system.build.vm" \
        -o "$DEVSHELL_ROOT/vm/$2" \
        "${@:3}" \
      && echo "export NIX_DISK_IMAGE=\"$DEVSHELL_ROOT/vm/$2.qcow2\"" > "$DEVSHELL_ROOT/vm/run-$2" \
      && echo "$DEVSHELL_ROOT/vm/$2/bin/run-$2-vm" >> "$DEVSHELL_ROOT/vm/run-$2" \
      && chmod +x "$DEVSHELL_ROOT/vm/run-$2"
    fi
    ;;

  "install")
    sudo nixos-install --flake "$DEVSHELL_ROOT#$2" "${@:3}"
    ;;

  "home")
    ref="$DEVSHELL_ROOT/#homeConfigurations.$3@$2.activationPackage"

    if [[ "$4" == "switch" ]]; then
      nix build "$ref" && result/activate &&
        unlink result

    else
      nix build "$ref" "${@:4}"
    fi
    ;;

  "repl")
    repl ${@:2}
    ;;

  *)
    sudo nixos-rebuild --flake "$DEVSHELL_ROOT#$1" "${@:2}"
    ;;
esac
