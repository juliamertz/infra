{
  config,
  system,
  inputs,
  ...
}: let
  dotfiles = inputs.dotfiles.packages.${system};
in {
  networking = {
    hostName = "gatekeeper";
    firewall.allowedTCPPorts = [80 443];
  };

  gateway = with config.gateway.lib; {
    hostname = "juliamertz.dev";

    services = {
      website = {
        config = redirect "https://github.com/juliamertz";
      };

      github = {
        subdomain = "gh";
        config = redirect "https://github.com/juliamertz";
      };

      nettenshop = {
        subdomain = "nettenshop-staging";
        config = reverseProxy {
          address = "http://10.0.1.2:5010";
          copyResponseHeaders = true;
        };
      };

      # jellyfin = {
      #   subdomain = "watch";
      #   config = lib.reverseProxy {
      #     address = "http://${hosts.hydra.internal}:8096";
      #     copyResponseHeaders = true;
      #   };
      # };
    };
  };

  environment.systemPackages = with dotfiles; [
    zsh
    tmux
    neovim-minimal
    git
  ];

  imports = [
    ./modules/gateway
  ];
}
