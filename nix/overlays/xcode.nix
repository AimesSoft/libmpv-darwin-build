final: prev:
let
  localXcodeApp = builtins.getEnv "LIBMPV_DARWIN_XCODE_APP";
in
{
  darwin = prev.darwin.overrideScope (
    finalDarwin: prevDarwin: {
      xcode_16_1 =
        if localXcodeApp != "" then
          prev.runCommand "Xcode.app" { } ''
            ln -s ${prev.lib.escapeShellArg localXcodeApp} "$out"
          ''
        else
          prevDarwin.xcode.overrideAttrs (prev: {
            outputHash = "sha256-1jyRJVyOmGA7fxRwBnxSJatnOFDu01RJ9aAQXJNuWBw=";
          });
      xcode = finalDarwin.xcode_16_1;
    }
  );
}
