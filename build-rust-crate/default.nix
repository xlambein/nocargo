{ lib, stdenv, buildPackages, rust, toml2json, jq }:
{ crateName
, version
, src
# [ { name = "foo"; drv = <derivation>; } ]
, dependencies ? []
, buildDependencies ? []
, features ? []
, nativeBuildInputs ? []
, ...
}@args:
let
  toCrateName = lib.replaceStrings [ "-" ] [ "_" ];

  mkRustcMeta = dependencies: features: let
    deps = lib.concatMapStrings (dep: dep.drv.rustcMeta) dependencies;
    feats = lib.concatStringsSep ";" features;
    final = "${crateName} ${version} ${feats} ${deps}";
  in
    lib.substring 0 16 (builtins.hashString "sha256" final);

  # Extensions are not included here.
  mkDeps = map ({ name, drv, ... }:
    "${toCrateName name}:${drv}/lib/lib${drv.crateName}-${drv.rustcMeta}:${drv.dev}/nix-support/rust-deps-closure");

in
stdenv.mkDerivation ({
  pname = "rust_${crateName}";
  inherit crateName version src features;

  builder = ./builder.sh;
  outputs = [ "out" "dev" ];

  buildRustcMeta = mkRustcMeta buildDependencies [];
  rustcMeta = mkRustcMeta dependencies features;

  rustBuildTarget = rust.toRustTarget stdenv.buildPlatform;
  rustHostTarget = rust.toRustTarget stdenv.hostPlatform;

  nativeBuildInputs = [ toml2json jq ] ++ nativeBuildInputs;

  BUILD_RUSTC = "${buildPackages.buildPackages.rustc}/bin/rustc";
  RUSTC = "${buildPackages.rustc}/bin/rustc";

  buildDependencies = mkDeps buildDependencies;
  dependencies = mkDeps dependencies;

  dontInstall = true;

} // removeAttrs args [
  "dependencies"
  "buildDependencies"
  "features"
  "nativeBuildInputs"
])