{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
  variant ? import ../../utils/default/variant.nix,
  flavor ? import ../../utils/default/flavor.nix,
}:

let
  name = "libs";
  version = import ../../utils/default/version.nix;

  archs = import ../../utils/constants/archs.nix;
  flavors = import ../../utils/constants/flavors.nix;
  variants = import ../../utils/constants/variants.nix;
  callPackage = pkgs.lib.callPackageWith {
    inherit
      pkgs
      os
      arch
      variant
      flavor
      ;
  };
  pname = import ../../utils/name/output.nix name;
in

let
  name = "${pname}-${os}-${arch}-${variant}-${flavor}-${version}";
in

if arch != archs.universal then
  let
    xctoolchainOtool = callPackage ../../utils/xctoolchain/otool.nix { };
    xctoolchainInstallNameTool = callPackage ../../utils/xctoolchain/install-name-tool.nix { };

    mpv = callPackage ../mk-pkg-mpv/default.nix { };
    ffmpeg = callPackage ../mk-pkg-ffmpeg/default.nix { };
    mbedtls = callPackage ../mk-pkg-mbedtls/default.nix { };
    fftoolsFfi = callPackage ../mk-pkg-fftools-ffi/default.nix { };
    libvorbis = callPackage ../mk-pkg-libvorbis/default.nix { };
    libogg = callPackage ../mk-pkg-libogg/default.nix { };
    dav1d = callPackage ../mk-pkg-dav1d/default.nix { };
    libxml2 = callPackage ../mk-pkg-libxml2/default.nix { };
    uchardet = callPackage ../mk-pkg-uchardet/default.nix { };
    libass = callPackage ../mk-pkg-libass/default.nix { };
    harfbuzz = callPackage ../mk-pkg-harfbuzz/default.nix { };
    fribidi = callPackage ../mk-pkg-fribidi/default.nix { };
    freetype = callPackage ../mk-pkg-freetype/default.nix { };
    libpng = callPackage ../mk-pkg-libpng/default.nix { };
    libvpx = callPackage ../mk-pkg-libvpx/default.nix { };
    libx264 = callPackage ../mk-pkg-libx264/default.nix { };

    deps =
      [
        mpv
        ffmpeg
        mbedtls
      ]
      ++ pkgs.lib.optionals (flavor == flavors.encodersgpl) [
        fftoolsFfi
        libvorbis
        libogg
      ]
      ++ pkgs.lib.optionals (variant == variants.video) [
        dav1d
        libxml2
        uchardet
        libass
        harfbuzz
        fribidi
        freetype
        libpng
      ]
      ++ pkgs.lib.optionals (variant == variants.video && flavor == flavors.encodersgpl) [
        libvpx
        libx264
      ];
  in
  pkgs.stdenvNoCC.mkDerivation {
    inherit name;
    pname = pname;
    inherit version;
    dontUnpack = true;
    enableParallelBuilding = true;
    nativeBuildInputs = [
      xctoolchainInstallNameTool
      xctoolchainOtool
    ];
    buildPhase = ''
      mkdir build

      # Copy dylibs except '*-subset.*.dylib'
      for dep in "${pkgs.lib.concatStringsSep " " deps}"; do
        find $dep/lib \
          -type f -name '*.dylib' \
          ! -name '*-subset.*.dylib' \
          -exec \
          cp {} ./build/ \
          \;
      done

      # Pull in transitive Nix store dylib dependencies so optional runtimes
      # like Vulkan/MoltenVK also make it into the packaged output.
      closure_changed=1
      while [ "$closure_changed" -eq 1 ]; do
        closure_changed=0
        while IFS= read -r file; do
          store_deps=$(otool -L "$file" | tail -n +3 | sed -n 's|.*\(/nix/store/[^ ]*\.dylib\).*|\1|p')
          for dep in $store_deps; do
            dep_name=$(basename "$dep")
            if [ ! -f "./build/$dep_name" ]; then
              cp "$dep" "./build/$dep_name"
              closure_changed=1
            fi
          done
        done < <(find ./build -maxdepth 1 -type f -name '*.dylib' | sort)
      done

      # Rename dylib libfoo.100.99.88.dylib -> libfoo.dylib
      for file in ./build/lib*.dylib; do
        new_path=$(echo $file | sed -E 's/^(.*\/lib[^.]*).*$/\1.dylib/')
        if [ $file != $new_path ]; then
          mv $file $new_path
        fi
      done

      # Change dylib's id libfoo.dylib -> @rpath/libfoo.dylib
      for file in ./build/lib*.dylib; do
        name=$(basename $file)
        install_name_tool -id @rpath/$name $file
      done

      # Change dylib's dep path /nix/store/**/libfoo.99.dylib -> @rpath/libfoo.99.dylib
      for file in ./build/lib*.dylib; do
        deps=$(otool -L $file | tail -n +3 | sed -n 's|.*\(/nix/store/[^ ]*\).*|\1|p')
        for dep in $deps; do
          name=$(basename $dep)
          install_name_tool -change $dep @rpath/$name $file
        done
      done

      # Change dylib's dep path @rpath/libfoo.99.dylib -> @rpath/libfoo.dylib
      for file in ./build/lib*.dylib; do
        deps=$(otool -L $file | tail -n +3 | sed -n 's|.*\(@rpath/[^ ]*\).*|\1|p')
        for dep in $deps; do
          name=$(echo $dep | sed -n 's|@rpath/\(lib[^.]*\).*|\1.dylib|p')
          install_name_tool -change $dep @rpath/$name $file
        done
      done

      # Use the platform C++ runtime instead of emitting invalid C++.framework
      # style wrappers for Nix libc++ runtime dylibs.
      for file in ./build/lib*.dylib; do
        install_name_tool -change @rpath/libc++.dylib /usr/lib/libc++.1.dylib $file 2>/dev/null || true
        install_name_tool -change @rpath/libc++abi.dylib /usr/lib/libc++abi.dylib $file 2>/dev/null || true
      done
      rm -f ./build/libc++.dylib ./build/libc++abi.dylib
    '';
    installPhase = ''
      cp -r build $out
    '';
  }
else
  let
    targets = import ./targets.nix;
    xctoolchainLipo = callPackage ../../utils/xctoolchain/lipo.nix { };

    depArchs = builtins.concatMap (
      target: if target.os == os && target.arch != archs.universal then [ target.arch ] else [ ]
    ) targets;
    deps = builtins.map (
      arch:
      import ./default.nix {
        inherit
          pkgs
          os
          arch
          variant
          flavor
          ;
      }
    ) depArchs;
  in
  pkgs.stdenvNoCC.mkDerivation {
    inherit name;
    pname = pname;
    inherit version;
    dontUnpack = true;
    enableParallelBuilding = true;
    nativeBuildInputs = [
      xctoolchainLipo
    ];
    buildPhase = ''
      mkdir build

      # Concatenate source directories and convert string to array
      deps="${pkgs.lib.concatStringsSep " " deps}"
      read -a deps <<< "$deps"

      lib_names=$(
        for dir in "''${deps[@]}"; do
          find "$dir" -maxdepth 1 -type f -name '*.dylib' -exec basename {} \;
        done | sort -u
      )

      for lib_name in $lib_names; do
        available=()
        for dir in "''${deps[@]}"; do
          if [ -f "$dir/$lib_name" ]; then
            available+=("$dir/$lib_name")
          fi
        done

        if [ "''${#available[@]}" -eq 1 ]; then
          echo "Warning: $lib_name is only present for one architecture; copying without lipo" 2> /dev/stderr
          cp "''${available[0]}" "./build/$lib_name"
          continue
        fi

        lipo -create "''${available[@]}" -output "./build/$lib_name"
      done
    '';
    installPhase = ''
      cp -r build $out
    '';
  }
