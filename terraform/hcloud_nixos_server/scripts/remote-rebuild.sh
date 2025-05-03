export NIX_CONFIG="extra-experimental-features = ${extra_experimental_features}"

nixos-rebuild switch --flake '${flake}'
