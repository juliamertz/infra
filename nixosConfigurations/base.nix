{
  pkgs,
  lib,
inputs,
  ...
}: let
  dotfiles = inputs.dotfiles.packages.${pkgs.system};
in {
  users.users.julia = {
    name = "julia";
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaSMVfNtTgKjZBn0OurWXDpNrV+soaog7W0Svv4vE40"
    ];
  };

  nix = {
    settings = {
      experimental-features = lib.mkDefault [
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

  environment.systemPackages = with dotfiles; [
    zsh
    tmux
    neovim-minimal
    git
  ];


  # programs.zsh.enable = true;
  users.defaultUserShell = dotfiles.zsh;

  system.stateVersion = "25.05";
}
