let
  explicitProfile = builtins.getEnv "LIBMPV_DARWIN_BUILD_PROFILE";
  hdrEnabled = builtins.getEnv "LIBMPV_DARWIN_ENABLE_MACOS_HDR";
in
if explicitProfile != "" then
  explicitProfile
else if builtins.elem hdrEnabled [ "1" "true" "TRUE" "yes" "YES" ] then
  "macos-hdr"
else
  "default"
