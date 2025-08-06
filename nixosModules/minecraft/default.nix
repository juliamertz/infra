{
  lib,
  inputs,
  ...
}: {
  imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];

  nixpkgs.overlays = [inputs.nix-minecraft.overlay];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "minecraft-server"
    ];

  services.minecraft-servers = {
    eula = lib.mkDefault true;

    managementSystem = {
      tmux.enable = lib.mkDefault false;
      systemd-socket.enable = lib.mkDefault true;
    };
  };

  # systemd.services.minecraft-server-fabric.serviceConfig = {
  #   KillMode = "exec"; # exec or mixed;
  #   TimeoutStopSec = 30;
  #   StandardInput = "socket";
  #   StandardOutput = "journal";
  #   StandardError = "journal";
  # };
}
