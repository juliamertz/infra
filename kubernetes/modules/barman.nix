{
  config,
  kubenix,
  crds,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    resources.objectStores.backblaze-b2.spec = {
      retentionPolicy = "30d";
      configuration = {
        destinationPath = "s3://backups-0snsf7rceJ/barman";
        endpointURL = "https://s3.eu-central-003.backblazeb2.com";
        s3Credentials = {
          accessKeyId = {
            name = "barman-credentials";
            key = "ACCESS_KEY_ID";
          };
          secretAccessKey = {
            name = "barman-credentials";
            key = "ACCESS_SECRET_KEY";
          };
        };
        wal.compression = "gzip";
      };
    };
  };

  submodule = {
    name = "barman";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
