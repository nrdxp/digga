let
  ufrContract = import ./ufrContract.nix;
  eachSystem = import ./eachSystem.nix;
in
supportedSystems:
  imprt: inputs:
    callargs: let
      f =  system: (ufrContract supportedSystems imprt inputs).${system} callargs;
    in eachSystem supportedSystems (system: f system)
