{
  albyHubSrc,
  autoPatchelfHook,
  buildGoModule,
  callPackage,
  lib,
  nodejs,
  patchelf,
  runCommand,
  stdenv,
  version,
  ...
}:
buildGoModule {
  pname = "alby-hub";
  inherit version;
  src = let
    albyHubUI = callPackage ./frontend.nix {inherit albyHubSrc version;};
  in
    runCommand "albyHubBackendSrc" {} ''
      mkdir $out
      cp -rT ${albyHubSrc} $out
      chmod -R +rw $out
      # add frontend drv output to src
      cp -r ${albyHubUI}/dist $out/frontend/dist
    '';
  vendorHash = "sha256-fHEDJ2M2uLMDrKisD/hhN5Bbfi+v7GBMMBJoXtybwIw=";
  proxyVendor = true;
  nativeBuildInputs = [autoPatchelfHook];
  ldFlags = ["-X 'github.com/getAlby/hub/version.Tag=${version}'"];
  buildInputs = [stdenv.cc.cc.lib];
  postInstall = ''
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

    # rename binary and remove references outside the nix store
    mv $out/bin/http $out/bin/alby-hub
    patchelf --shrink-rpath --allowed-rpath-prefixes /nix/store $out/bin/alby-hub
  '';
}
