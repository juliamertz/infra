{
  craneLib,
  filter,
  #
  lib,
  pkg-config,
  stdenv,
  openssl,
  libiconv,
}:
craneLib.buildPackage rec {
  pname = "controllers";
  version = "v0.1.0";

  src = filter {
    root = ../.;
    include = [
      ../Cargo.toml
      ../Cargo.lock
      ../cli/Cargo.toml
      ./Cargo.toml
      ./src
    ];
  };

  cargoExtraArgs = "--bin infra-controllers";
  cargoVendorDir = craneLib.vendorCargoDeps {inherit src;};

  strictDeps = true;

  nativeBuildInputs =
    [pkg-config]
    ++ lib.optionals stdenv.buildPlatform.isDarwin [libiconv];

  buildInputs = [openssl];
}
