rec {
  port = 51820;                                                                                                                                    

  publicKeys = {
    julia = "VcEu1t2j+mmiPKI8NBusFp1Qgi/VhblZencgsM4qWwo=";
    server = "YOkwBtwqQrj9XSVuLGfbugYKVSunXGH/+IPHL4XACTE=";
  };

  server = {
    inherit port;
    ipRange = "10.100.0.1/24";
  };

  peers = {
    main = {
      publicKey = publicKeys.server;
      allowedIPs = ["10.100.0.1/32"];
    };
    gatekeeper = {
      publicKey = publicKeys.server;
      allowedIPs = ["10.100.0.2/32"];
    };
    macbook = {
      publicKey = publicKeys.julia;
      allowedIPs = ["10.100.0.6/32"];
    };
  };

  withMask = ip: mask: "${ip}/${builtins.toString mask}";
}
