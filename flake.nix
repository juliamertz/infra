{
  inputs = {
    nixpkgs.follows = "srvos/nixpkgs";
    srvos.url = "github:nix-community/srvos";
    systems.url = "github:nix-systems/default";
    dotfiles.url = "github:juliamertz/dotfiles";
    sops.url = "github:Mic92/sops-nix";
  };

  outputs = {
    nixpkgs,
    systems,
    ...
  } @ inputs: let
    forAllSystems = fun:
      nixpkgs.lib.genAttrs (import systems) (system:
        fun nixpkgs.legacyPackages.${system});
  in {
    nixosConfigurations = import ./nixosConfigurations {
      inherit inputs;
      inherit (nixpkgs) lib;
    };

    devShells = forAllSystems (pkgs: {
      default = import ./shell.nix pkgs;
    });

    colmena = {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };
      };

      main = {
        name,
        nodes,
        pkgs,
        ...
      }: {
        networking.hostName = "main";

        # sops.age.keyFile = "/etc/sops/age/keys.txt";

        # services.nettenshop = {
        #   enable = true;
        #   openFirewall = true;
        #   sopsFile = ../../../secrets/nettenshop.yaml;
        #   extraUsers = ["julia"];
        # };
        #
        # services.wireguard-client = {
        #   enable = true;
        #   ipRange = "10.100.0.2/24";
        #   serverIp = "10.0.1.1";
        # };

        imports = [
          # ../../modules/nettenshop
          # ../../modules/wireguard
          # inputs.sops.nixosModules.sops
        ];

        # boot.isContainer = true;
        # time.timeZone = nodes.host-b.config.time.timeZone;
      };

      host-b = {
        deployment = {
          targetHost = "somehost.tld";
          targetPort = 1234;
          targetUser = "luser";
        };
        boot.isContainer = true;
        time.timeZone = "America/Los_Angeles";
      };
    };
  };
}
