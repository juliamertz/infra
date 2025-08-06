{
  inputs,
  lib,
  name,
  nodes,
  pkgs,
  config,
  ...
}: {
  networking.hostName = name;

  networking.firewall.allowedTCPPorts = [22];

  imports = [
    ./gateway.nix
    ./wireguard.nix
  ];
}
