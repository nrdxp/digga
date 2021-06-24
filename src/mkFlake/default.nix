{ lib, deploy }:
let
  inherit (builtins) mapAttrs attrNames attrValues head isFunction;
in

_: { self, ... } @ args:
let

  evaled = lib.mkFlake.evalArgs {
    inherit args;
  };

  cfg = evaled.config;

  otherArguments = removeAttrs args (attrNames evaled.options);

  defaultModules = [
    (lib.modules.hmDefaults {
      specialArgs = cfg.home.importables;
      modules = cfg.home.modules ++ cfg.home.externalModules;
    })
    (lib.modules.globalDefaults {
      inherit self;
    })
    ({ ... }@args: {
      lib.specialArgs = args.specialArgs or (builtins.trace ''
        WARNING: specialArgs is not accessibly by the module system which means you
        are likely using NixOS 20.09. Profiles testing and custom builds (ex: iso)
        are not supported in 20.09 and using them could result in infinite
        recursion errors. It is recommended to update to 21.05 to use either feature.
      ''
        { });
    })
    lib.modules.customBuilds
  ];

  stripChannel = channel: removeAttrs channel [
    # arguments in our channels api that shouldn't be passed to fup
    "overlays"
  ];

  # evalArgs sets channelName and system to null by default
  # but for proper default handling in fup, null args have to be removed
  stripHost = args: removeAttrs (lib.filterAttrs (_: arg: arg != null) args) [
    # arguments in our hosts/hostDefaults api that shouldn't be passed to fup
    "externalModules"
  ];

in
lib.systemFlake (lib.mergeAny
  {
    inherit self;
    inherit (self) inputs;
    inherit (cfg) channelsConfig supportedSystems;

    hosts = lib.mapAttrs (_: stripHost) cfg.nixos.hosts;

    channels = mapAttrs
      (name: channel:
        stripChannel (channel // {
          # pass channels if "overlay" has three arguments
          overlaysBuilder = channels: lib.unifyOverlays channels channel.overlays;
        })
      )
      cfg.channels;

    sharedOverlays = [
      (final: prev: {
        __dontExport = true;
        lib = prev.lib.extend (lfinal: lprev: {
          # digga lib can be accessed in packages as lib.digga
          digga = lib;
        });
      })
    ];

    hostDefaults = lib.mergeAny (stripHost cfg.nixos.hostDefaults) {
      specialArgs = cfg.nixos.importables;
      modules = cfg.nixos.hostDefaults.externalModules ++ defaultModules;
    };

    nixosModules = lib.exporters.modulesFromList cfg.nixos.hostDefaults.modules;

    homeModules = lib.exporters.modulesFromList cfg.home.modules;

    devshellModules = lib.exporters.modulesFromList cfg.devshell.modules;

    overlays = lib.exporters.internalOverlays {
      # since we can't detect overlays owned by self
      # we have to filter out ones exported by the inputs
      # optimally we would want a solution for NixOS/nix#4740
      inherit (self) pkgs inputs;
    };

    outputsBuilder = channels:
      let
        defaultChannel = channels.${cfg.nixos.hostDefaults.channelName};
        system = defaultChannel.system;
        defaultOutputsBuilder = {

          packages = lib.exporters.fromOverlays self.overlays channels;

          checks =
            (
              if (
                (builtins.hasAttr "homeConfigurations" self) &&
                (self.homeConfigurations != { })
              ) then
                lib.mapAttrs (n: v: v.activationPackage) self.homeConfigurations
              else { }
            )
            //
            (
              if (
                (builtins.hasAttr "deploy" self) &&
                (self.deploy.nodes != { }) &&
                (builtins.hasAttr "nixosConfigurations" self) &&
                (self.nixosConfigurations != { })
              ) then
                let
                  sieve = n: _: self.nixosConfigurations.${n}.config.nixpkgs.system == system;
                  deployHostsOnSystem = lib.filterAttrs sieve self.deploy.nodes;

                  # Arbitrarily test _first_ host only
                  hostName = builtins.head (builtins.attrNames deployHostsOnSystem);
                  host = self.nixosConfigurations.${hostName};
                  deployChecks = deploy.lib.${system}.deployChecks { nodes = deployHostsOnSystem; };

                in
                if (deployHostsOnSystem != { }) then {
                  "allProfilesTestFor-${hostName}" = lib.pkgs-lib.tests.profilesTest {
                    inherit host; pkgs = defaultChannel;
                  };
                } else { }
              else { }
            )
          ;

          devShell = lib.pkgs-lib.shell {
            pkgs = defaultChannel;
            extraModules = cfg.devshell.modules ++ cfg.devshell.externalModules;
          };

        };

      in
      lib.mergeAny defaultOutputsBuilder (cfg.outputsBuilder channels);

  }
  otherArguments # for overlays list order
)
