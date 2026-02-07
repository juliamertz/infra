{
  config,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    ../../../type/gateway.nix
  ];

  config.kubernetes = {
    namespace = "theme-park";

    resources.namespaces.theme-park = {};

    resources.configMaps.theme-park-nginx.data = {
      "default.conf" = ''
        server {
            listen 80 default_server;
            listen 443 ssl http2;
            server_name _;
            index index.html index.htm index.php;

            location / {
                alias /config/www/;
                try_files $uri $uri/ =404;
            }

            location  /themepark {return 302  $scheme://$http_host/themepark/;}
            location /themepark/ {
                alias /config/www/;
                sub_filter_types *;
                sub_filter 'url("/css/' 'url("/themepark/css/';
                sub_filter 'url(/resources/' 'url(/themepark/resources/';
                sub_filter_once off;
                try_files $uri $uri/ =404;
            }
            # Don't cache
            add_header Last-Modified $date_gmt;
            add_header Cache-Control 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';
            if_modified_since off;
            expires -1;
            etag off;
        }
      '';
    };

    resources.deployments.theme-park = {
      metadata.labels.app = "theme-park";
      spec = {
        replicas = 1;
        selector.matchLabels.app = "theme-park";
        template = {
          metadata.labels.app = "theme-park";
          spec = {
            containers = [
              {
                name = "theme-park";
                image = "ghcr.io/themepark-dev/theme.park:1.22.0";
                ports = [
                  {
                    name = "http";
                    containerPort = 80;
                  }
                  {
                    name = "https";
                    containerPort = 443;
                  }
                ];
                volumeMounts = [
                  {
                    name = "nginx-conf";
                    mountPath = "/defaults/nginx/site-confs/default.conf";
                    subPath = "default.conf";
                  }
                ];
                resources = {
                  requests = {
                    cpu = "10m";
                    memory = "20Mi";
                  };
                  limits = {
                    cpu = "50m";
                    memory = "50Mi";
                  };
                };
                readinessProbe = {
                  httpGet = {
                    path = "/";
                    port = 80;
                  };
                  initialDelaySeconds = 3;
                  periodSeconds = 3;
                };
              }
            ];
            volumes = [
              {
                name = "nginx-conf";
                configMap.name = "theme-park-nginx";
              }
            ];
          };
        };
      };
    };

    resources.services.theme-park = {
      metadata.labels.app = "theme-park";
      spec = {
        type = "ClusterIP";
        ports = [
          {
            name = "http";
            protocol = "TCP";
            port = 80;
            targetPort = 80;
          }
        ];
        selector.app = "theme-park";
      };
    };

    resources.referenceGrants.allow-httproute-across-namespaces.spec = {
      from = [
        {
          group = "gateway.networking.k8s.io";
          kind = "HTTPRoute";
          namespace = "authelia";
        }
      ];
      to = [
        {
          group = "";
          kind = "Service";
          name = "theme-park";
        }
      ];
    };
  };

  config.submodule = {
    name = "theme-park";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
