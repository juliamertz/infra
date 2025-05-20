rec {
  port = 51820;

  server = {
    inherit port;
    ipRange = "10.100.0.0/24";
    publicKey = peers.gatekeeper.publicKey;
  };

  peers = {
    gatekeeper = {
      publicKey = "+UMRNrDpies7uCO4wCgxKdyDuN1/FpmIilO8/NO66Uo=";
      subnetIp = "10.100.0.1";
    };
    main = {
      publicKey = "tVHanBrvOyUFA7Gf6CE3dILyZN511AahfO1trLyBxQ4=";
      subnetIp = "10.100.0.2";
    };
    macbook = {
      publicKey = "dU+x5zu/5v3ieeJgsnLDzC28suMl27jfufSrGzz5zQY=";
      subnetIp = "10.100.0.6";
    };
    workstation = {
      publicKey = "W6S6BMwUsg/iTOONOgQreAvUbvBBPo3P7zXyFpslp0w=";
      subnetIp = "10.100.0.5";
    };
    homelab = {
      publicKey = "VcEu1t2j+mmiPKI8NBusFp1Qgi/VhblZencgsM4qWwo=";
      subnetIp = "10.100.0.4";
    };
  };
}
