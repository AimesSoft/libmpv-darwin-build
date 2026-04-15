# Same API as `builtins.fetchTarball`, but here `sha256` corresponds to the hash
# of the non-extracted tarball, not the NAR hash once decompressed
{
  pkgs ? import ../../utils/default/pkgs.nix,
  name,
  url,
  sha256,
}:
let
  tarball = import ../fetch-file/default.nix {
    inherit
      name
      url
      sha256
      ;
  };
in
pkgs.runCommand name { } ''
  mkdir $out
  tar -xvf ${tarball} --strip-components=1 -C $out
''
