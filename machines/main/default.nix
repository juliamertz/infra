{
  inputs,
  name,
  nodes,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [ ];

  networking.hostName = name;

  # fileSystems. "/data" = {
  #   device = "/dev/sdb";
  #   fsType = "ext4";
  #   options = ["data=journal"];
  # };
  #
}
