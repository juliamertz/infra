{
  inputs,
  config,
  system,
  ...
}: let
  dotfiles = inputs.dotfiles.packages.${system};
in {
  networking.hostName = "main";

  environment.systemPackages = with dotfiles; [
    zsh
    tmux
    neovim-minimal
    lazygit
    git
  ];

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  services.nettenshop = {
    enable = true;
    openFirewall = true;
  };
  users.users.julia.extraGroups = [config.services.nettenshop.group];

  imports = [
    ./services/nettenshop.nix
    inputs.sops.nixosModules.sops
  ];
}
