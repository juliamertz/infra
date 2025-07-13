{
  name,
  config,
  ...
}: {
  imports = [../../nixosModules/wireguard];

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

  services.prometheus.exporters.wireguard = {
    enable = true;
  };
}
