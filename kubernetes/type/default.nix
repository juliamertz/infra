{kubenix, ...}: {
  imports = [
    kubenix.modules.k8s

    ./fluxcd.nix
    ./cert-manager.nix
    ./gateway.nix
    ./dragonfly-operator.nix
  ];
}
