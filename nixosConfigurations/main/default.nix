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

  users.users.julia.extraGroups = [config.services.nettenshop.group];

  imports = [
    ./services/valnetten.nix
    inputs.sops.nixosModules.sops
  ];
}
