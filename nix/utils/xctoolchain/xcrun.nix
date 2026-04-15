{
  pkgs ? import ../default/pkgs.nix,
}:

pkgs.runCommand "mk-xctoolchain-xcrun" { } ''
  mkdir -p $out/bin

  cat > $out/bin/xcrun <<EOF
#!/usr/bin/env sh

export DEVELOPER_DIR=${pkgs.darwin.xcode}/Contents/Developer
sdk_path="${pkgs.darwin.xcode}/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

sdk_version() {
  sed -n 's/.*"Version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "\$sdk_path/SDKSettings.json"
}

if [ "\$1" = "-find" ] || [ "\$1" = "--find" ]; then
  if [ "\$2" = "swiftc" ]; then
    echo "${pkgs.darwin.xcode}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
    exit 0
  fi
fi

if [ "\$1" = "--sdk" ] && [ "\$2" = "macosx" ]; then
  if [ "\$3" = "--show-sdk-path" ]; then
    echo "\$sdk_path"
    exit 0
  fi

  if [ "\$3" = "--show-sdk-version" ]; then
    sdk_version
    exit 0
  fi
fi

exec /usr/bin/xcrun "\$@"
EOF

  chmod +x $out/bin/xcrun
  patchShebangs $out/bin/xcrun
''
