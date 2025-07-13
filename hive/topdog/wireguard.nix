{
  name,
  config,
  ...
}: {
  imports = [
    ../../nixosModules/wireguard
  ];

  sops.secrets.wireguardPrivateKey = {
    key = name;
    owner = "julia";
    sopsFile = ../../secrets/wireguard.yaml;
  };

  services.wireguard-client = let
    inherit (config.services.wireguard-client) net;
  in {
    enable = true;
    ipRange = "${net.peers.${name}.subnetIp}/23";
    serverIp = "10.0.1.1";
    privateKeyFile = config.sops.secrets.wireguardPrivateKey.path;
  };
}
