rec {
  port = 51820;                                                                                                                                    

  publicKeys = {
    gatekeeper = "+UMRNrDpies7uCO4wCgxKdyDuN1/FpmIilO8/NO66Uo=";
    main = "tVHanBrvOyUFA7Gf6CE3dILyZN511AahfO1trLyBxQ4=";
    macbook = "dU+x5zu/5v3ieeJgsnLDzC28suMl27jfufSrGzz5zQY=";
    workstation = "W6S6BMwUsg/iTOONOgQreAvUbvBBPo3P7zXyFpslp0w=";
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
      publicKey = publicKeys.macbook;
      allowedIPs = ["10.100.0.6/32"];
    };
    workstation = {
      publicKey = publicKeys.workstation;
      allowedIPs = ["10.100.0.5/32"];
    };
  };

  withMask = ip: mask: "${ip}/${builtins.toString mask}";
}
