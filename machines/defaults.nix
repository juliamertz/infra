inputs: {
  pkgs,
  ...
}: let
  dotfiles = inputs.dotfiles.packages.${pkgs.system};
in {
  imports = [
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-terminfo
    inputs.sops.nixosModules.sops
  ];

  networking.hostName = "main";

  networking = {
    useHostResolvConf = false;
    interfaces.enp7s0.useDHCP = true;
    firewall.trustedInterfaces = ["enp7s0"];
  };

  # # age key is placed here as part of terraform init
  # sops.age.keyFile = lib.mkDefault "/etc/sops/age/keys.txt";

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

      trusted-users = [
        "root"
        "julia"
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  environment.sessionVariables = {
    TERM = "xterm-256color";
  };

  system.stateVersion = "25.05";
}
