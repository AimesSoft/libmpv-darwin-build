{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "libpng";
  packageLock = (import ../../../packages.lock.nix).${name};
  packagePatchLock = (import ../../../packages.lock.nix).libpngPatch;
  inherit (packageLock) version;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
  libpngPatch = import ../../utils/fetch-file/default.nix {
    name = "${pname}-patch-${version}";
    inherit (packagePatchLock) url sha256;
  };
  patchedSource =
    pkgs.runCommand "${pname}-patched-source-${version}"
      {
        nativeBuildInputs = [
          pkgs.perl
          pkgs.unzip
          pkgs.rsync
        ];
      }
      ''
        cp -r ${src} src
        export src=$PWD/src
        chmod -R 777 $src

        # extract and patch libpng dependency
        unzip ${libpngPatch} -d libpng-patch
        rsync -a libpng-patch/libpng-*/ $src/

        # Xcode 26 clang predefines TARGET_OS_MAC for modern Darwin builds.
        # libpng treats that as classic Mac OS and tries to include <fp.h>,
        # which no longer exists in current macOS SDKs.
        perl -0pi -e 's/defined\(THINK_C\) \|\| defined\(__SC__\) \|\| defined\(TARGET_OS_MAC\)/defined(THINK_C) || defined(__SC__) || (defined(TARGET_OS_MAC) \&\& !defined(__APPLE__))/g' $src/pngpriv.h

        cp -r $src $out
      '';
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  src = patchedSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
  ];
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out
  '';
  buildPhase = ''
    meson compile -vC build
  '';
  installPhase = ''
    meson install -C build
  '';
}
