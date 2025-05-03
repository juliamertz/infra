export NIX_CONFIG="extra-experimental-features = ${experimental_features}"

nixos-rebuild switch --flake '${flake}'
