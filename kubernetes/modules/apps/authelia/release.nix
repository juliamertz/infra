{
  kubernetes = {
    resources.helmRepositories.authelia.spec = {
      interval = "1h";
      url = "https://charts.authelia.com";
    };

    resources.helmReleases.authelia.spec = {
      interval = "1h";
      chart.spec = {
        chart = "authelia";
        version = "0.10.49";
        sourceRef = {
          kind = "HelmRepository";
          name = "authelia";
        };
      };
      values = import ./values.nix;
    };
  };
}
