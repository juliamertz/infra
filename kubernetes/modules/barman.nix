{
  config,
  kubenix,
  crds,
  lib,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  options.submodule.args = with lib; {
    s3Bucket = mkOption {
      type = types.str;
      default = "backups-0snsf7rceJ";
    };
    endpointUrl = mkOption {
      type = types.str;
      default = "https://s3.eu-central-003.backblazeb2.com";
    };
  };

  config.kubernetes = {
    resources.objectStores.backblaze-b2.spec = {
      retentionPolicy = "30d";
      configuration = {
        destinationPath = "s3://${config.submodule.args.s3Bucket}/barman";
        endpointURL = config.submodule.args.endpointUrl;
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

  config.submodule = {
    name = "barman";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
