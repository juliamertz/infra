{...}: {
  services.loki = {
    enable = true;

    configuration = {
      auth_enabled = false;

      server = {
        http_listen_port = 3100;
      };

      common = {
        ring = {
          instance_addr = "127.0.0.1";
          kvstore = {
            store = "inmemory";
          };
        };
        replication_factor = 1;
        path_prefix = "/tmp/loki";
      };

      schema_config = {
        configs = [
          {
            from = "2022-01-22";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };
      storage_config = {
        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      limits_config = {
        retention_period = "30d"; # e.g., 30 days
        # Enforce limits to prevent Loki from using too much memory/CPU for queries
        # max_query_series = 5000;
        # max_query_parallelism = 32;
      };
    };
  };
}
