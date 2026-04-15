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
  envPathValue =
    if envVar != "" then
      builtins.getEnv envVar
    else
      "";
  envPath =
    if envPathValue != "" then
      /. + envPathValue
    else
      null;
  chosenLocalPath =
    if envPath != null then
      envPath
    else if localPath != null && builtins.pathExists localPath then
      localPath
    else
      null;
in
if chosenLocalPath != null then
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
