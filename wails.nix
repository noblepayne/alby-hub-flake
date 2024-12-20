{
  albyHubSrc,
  autoPatchelfHook,
  buildGoModule,
  callPackage,
  fetchYarnDeps,
  fixup-yarn-lock,
  gcc,
  go,
  gtk3,
  lib,
  nodejs,
  patchelf,
  pkg-config,
  runCommand,
  stdenv,
  version,
  wails,
  webkitgtk_4_1,
  yarn,
  ...
}: let
  offlineCache = fetchYarnDeps {
    yarnLock = "${albyHubSrc}/frontend/yarn.lock";
    hash = "sha256-QFhIpJkd426c3GaDSpI36CxlNGVKQoSN8wDgAVh9Ee4=";
  };
  deps = stdenv.mkDerivation {
    pname = "alby-hub-deps";
    inherit version;
    src = albyHubSrc;
    nativeBuildInputs = [go];
    buildPhase = ''
      mkdir -p $out
      export HOME=$(mktemp -d)
      export GOCACHE=$(mktemp -d)
      export GOPATH=$(mktemp -d)
      export GOOS=linux
      export GOARCH=${
        if stdenv.isAarch64
        then "arm64"
        else "amd64"
      }
      mkdir -p "''${GOPATH}/pkg/mod/cache/download"
      go mod download all
      rm -rf "''${GOPATH}/pkg/mod/cache/download/sumdb"
      cp -rT "''${GOPATH}/pkg/mod/cache/download" $out
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-/fOx3i+kb8reloVF3ZfHoKRiochKg4jIBbe7MYDOr00=";
    dontFixup = true;
  };
in
  stdenv.mkDerivation {
    pname = "alby-hub";
    inherit version;
    src = let
      albyHubUI = callPackage ./frontend.nix {
        inherit albyHubSrc version;
        buildWails = true;
      };
    in
      runCommand "albyHubBackendSrc" {} ''
        mkdir $out
        cp -rT ${albyHubSrc} $out
        chmod -R +rw $out
        # add frontend drv output to src
        cp -r ${albyHubUI}/dist $out/frontend/dist
      '';
    nativeBuildInputs = [autoPatchelfHook wails nodejs yarn fixup-yarn-lock];
    buildInputs = [
      go
      pkg-config
      gcc
      stdenv.cc
      stdenv.cc.cc.lib
      gtk3
      webkitgtk_4_1
    ];
    buildPhase = ''
      export HOME=$(mktemp -d)
      export GOCACHE=$(mktemp -d)
      export GOPATH=$(mktemp -d)
      export CGO_ENABLED=1
      export CC=gcc
      export GOOS=linux
      export GOARCH=${
        if stdenv.isAarch64
        then "arm64"
        else "amd64"
      }
      # inspired by proxyVendor in buildGoModule
      export GOPROXY="file://${deps}"
      export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${stdenv.cc.cc.lib.outPath}/lib"

      # TODO: avoid double builds. This build is only needed to generate bindings.
      wails build --platform linux/amd64 -webview2 embed -o alby-hub -tags "wails" -ldflags "-X 'github.com/getAlby/hub/version.Tag=${version}'" -m -nosyncgomod -s

      # install frontend deps (needs to run after bindings exist)
      pushd frontend
      yarn config --offline set yarn-offline-mirror ${offlineCache}
      cp "${offlineCache}/yarn.lock" .
      fixup-yarn-lock yarn.lock
      yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
      # make node_modules binaries usable and accessible
      patchShebangs node_modules
      export PATH="$PWD/node_modules/.bin:$PATH"
      # yarn -> yarn --offline in package.json scripts
      sed -i 's/yarn/yarn --offline/g' package.json
      # build and install ui
      yarn --offline build:wails
      popd

      # final build
      wails build --platform linux/amd64 -webview2 embed -o alby-hub -tags "wails" -ldflags "-X 'github.com/getAlby/hub/version.Tag=${version}'" -m -nosyncgomod -s

      mkdir -p $out/bin
      cp build/bin/alby-hub $out/bin
      patchelf --shrink-rpath --allowed-rpath-prefixes /nix/store $out/bin/alby-hub

      # copy libraries needed for runtime
      workdir=$(mktemp -d)
      cp go.mod $workdir
      cp go.sum $workdir
      cp build/docker/copy_dylibs.sh $workdir
      pushd $workdir
      bash copy_dylibs.sh $GOARCH
      rm go.mod go.sum copy_dylibs.sh
      mkdir -p $out/lib
      cp -rT . $out/lib
      popd
    '';
  }
