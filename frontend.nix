{
  albyHubSrc,
  fetchYarnDeps,
  fixup-yarn-lock,
  nodejs,
  stdenv,
  version,
  yarn,
  ...
}: let
  offlineCache = fetchYarnDeps {
    yarnLock = "${albyHubSrc}/frontend/yarn.lock";
    hash = "sha256-QFhIpJkd426c3GaDSpI36CxlNGVKQoSN8wDgAVh9Ee4=";
  };
in
  stdenv.mkDerivation {
    pname = "alby-hub-ui";
    inherit version;
    src = "${albyHubSrc}/frontend";
    nativeBuildInputs = [yarn nodejs fixup-yarn-lock];
    buildPhase = ''
      # install deps
      export HOME=$(mktemp -d)
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
      yarn --offline build:http
      mkdir -p $out
      mv dist $out
    '';
  }
