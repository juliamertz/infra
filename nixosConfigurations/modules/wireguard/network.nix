rec {
  port = 51820;                                                                                                                                    

  publicKeys = {
    julia = "W6S6BMwUsg/iTOONOgQreAvUbvBBPo3P7zXyFpslp0w=";
    main = "YOkwBtwqQrj9XSVuLGfbugYKVSunXGH/+IPHL4XACTE=";
    gatekeeper = "1RhicoTx80WUc/1QuyPQupkyMEBq8eQmIgUuzp2dHBM=";
  };

  server = {
    publicKey = peers.gatekeeper.publicKey;
    inherit port;
    ipRange = "10.100.0.0/24";
  };

  peers = {
    gatekeeper = {
      publicKey = publicKeys.gatekeeper;
      allowedIPs = ["10.100.0.1/32"];
    };
    main = {
      publicKey = publicKeys.main;
      allowedIPs = ["10.100.0.2/32"];
    };
    macbook = {
      publicKey = publicKeys.julia;
      allowedIPs = ["10.100.0.6/32"];
    };
  };

  withMask = ip: mask: "${ip}/${builtins.toString mask}";
}
