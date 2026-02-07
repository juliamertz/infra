{...}: {
  imports = [
    ./fluxcd.nix
    ./cert-manager.nix
    ./gateway.nix
    ./dragonfly-operator.nix
    ./cert-vandal.nix
    ./cloudnative-pg.nix
    ./headscale.nix
    ./monitoring.nix
    ./barman.nix
  ];
}
