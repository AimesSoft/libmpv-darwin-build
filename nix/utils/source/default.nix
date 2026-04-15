{
  pkgs ? import ../default/pkgs.nix,
}:

{
  name,
  version,
  url ? null,
  sha256 ? null,
  envVar ? "",
  localPath ? null,
}:

let
  envPath =
    if envVar != "" then
      builtins.getEnv envVar
    else
      "";
  chosenLocalPath =
    if envPath != "" then
      envPath
    else if localPath != null && builtins.pathExists localPath then
      toString localPath
    else
      "";
in
if chosenLocalPath != "" then
  pkgs.lib.cleanSourceWith {
    name = "${name}-source-${version}-local";
    src = builtins.path {
      path = chosenLocalPath;
      name = "${name}-source-local";
    };
    filter =
      path: type:
      let
        base = builtins.baseNameOf (toString path);
      in
      !(builtins.elem base [
        ".direnv"
        ".git"
        "build"
        "result"
      ]);
  }
else if url != null && sha256 != null then
  pkgs.callPackage ../fetch-tarball/default.nix {
    name = "${name}-source-${version}";
    inherit url sha256;
  }
else
  abort "libmpv-darwin-build: no source available for ${name}"
