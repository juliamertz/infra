rec {
  port = 51820;

  server = {
    inherit port;
    ipRange = "10.100.0.0/23";
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
    topdog = {
      publicKey = "MnYfEkLWYp+a+XdU0O8VRfmZQVR6+IswMGaPGyjNMGg=";
      subnetIp = "10.100.0.3";
    };

    homelab = {
      publicKey = "VcEu1t2j+mmiPKI8NBusFp1Qgi/VhblZencgsM4qWwo=";
      subnetIp = "10.100.1.1";
    };
    workstation = {
      publicKey = "W6S6BMwUsg/iTOONOgQreAvUbvBBPo3P7zXyFpslp0w=";
      subnetIp = "10.100.1.2";
    };
    macbook = {
      publicKey = "dU+x5zu/5v3ieeJgsnLDzC28suMl27jfufSrGzz5zQY=";
      subnetIp = "10.100.1.3";
    };
  };
}
