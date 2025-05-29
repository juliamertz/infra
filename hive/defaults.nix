inputs: {pkgs, ...}: let
  dotfiles = inputs.dotfiles.packages.${pkgs.system};
in {
  imports = [
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-terminfo
    inputs.sops.nixosModules.sops
  ];

  networking = {
    useHostResolvConf = false;

    # enable networking for the internal hetzner network
    interfaces.enp7s0.useDHCP = true;
    firewall.trustedInterfaces = ["enp7s0"];
  };

  services.fail2ban.enable = true;

  environment.systemPackages = with dotfiles; [
    zsh
    tmux
    neovim-minimal
    git
    scripts
  ];

  users.defaultUserShell = dotfiles.zsh;

  users.users = let
    authorizedKeys = [
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaSMVfNtTgKjZBn0OurWXDpNrV+soaog7W0Svv4vE40" # old
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfVB8IMsb81U7ySvg82PTlBhnKlQ7Lqs50p4XU1nAv3"
    ];
  in {
    root.openssh.authorizedKeys.keys = authorizedKeys;
    julia = {
      name = "julia";
      isNormalUser = true;
      useDefaultShell = true;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = authorizedKeys;
    };
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];

      substituters = ["https://juliamertz.cachix.org"];
      trusted-public-keys = ["juliamertz.cachix.org-1:l9jCGk7vAKU5kS07eulGJiEsZjluCG5HTczsY2IL2aw="];

      trusted-users = [
        "root"
        "julia"
      ];
    };
  };

  system.stateVersion = "25.05";
  # time.timeZone = nodes.host-b.config.time.timeZone;
}
