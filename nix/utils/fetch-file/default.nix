{
  name,
  url,
  sha256,
}:

let
  archiveBasenameMatch = builtins.match ".*/([^/?]+)(\\?.*)?" url;
  archiveBasename =
    if archiveBasenameMatch == null then
      name
    else
      builtins.elemAt archiveBasenameMatch 0;
  explicitCacheDir = builtins.getEnv "LIBMPV_DARWIN_FETCH_CACHE_DIR";
  localFile =
    if explicitCacheDir != "" then
      "${explicitCacheDir}/${archiveBasename}"
    else
      "";
in
if localFile != "" && builtins.pathExists localFile then
  builtins.path {
    path = localFile;
    name = archiveBasename;
  }
else
  builtins.fetchurl {
    inherit url sha256;
  }
