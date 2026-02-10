{
  kubernetes = {
    resources.cnpgClusters.authelia-db.spec = {
      instances = 2;
      primaryUpdateStrategy = "unsupervised";
      primaryUpdateMethod = "switchover";
      enableSuperuserAccess = false;
      storage = {
        size = "1Gi";
        storageClass = "longhorn-local";
        resizeInUseVolumes = true;
      };
      bootstrap = {
        initdb = {
          database = "authelia";
          owner = "authelia";
        };
      };
    };

    resources.dragonflies.authelia-cache.spec = {
      image = "docker.dragonflydb.io/dragonflydb/dragonfly:latest";
      replicas = 1;
      resources = {
        limits = {
          cpu = "100m";
          memory = "512Mi";
        };
        requests = {
          cpu = "100m";
          memory = "512Mi";
        };
      };
    };
  };
}
