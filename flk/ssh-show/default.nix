{ stdenv }:
let
  name = "ssh-show-ed25519";
  description = "ssh-show-ed25519 <user@hostName> | Show target host's SSH ed25519 key";
in
stdenv.mkDerivation {
  inherit name;

  src = ./ssh-show.sh;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    install $src $out/bin/${name}
  '';

  checkPhase = ''
    ${stdenv.shell} -n -O extglob $out/bin/${name}
  '';

  meta = { inherit description; };
}
