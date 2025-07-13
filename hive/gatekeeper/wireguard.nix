{
  name,
  config,
  ...
}: {
  sops.secrets.wireguardPrivateKey = {
    key = name;
    owner = "julia";
    sopsFile = ../../secrets/wireguard.yaml;
  };

  services.wireguard-server = {
    enable = true;
    enableForwarding = true;
    privateKeyFile = config.sops.secrets.wireguardPrivateKey.path;
    externalInterface = "eth0";
  };

  imports = [
    ../../nixosModules/wireguard
  ];
}
