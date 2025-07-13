{name, ...}: {
  networking.firewall.allowedTCPPorts = [22];

  imports = [
    ./gateway.nix
    ./wireguard.nix
  ];
}
