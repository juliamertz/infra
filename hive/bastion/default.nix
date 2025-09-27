{
  inputs,
  name,
  nodes,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [];

  services.nginx = {
    enable = true;
    config = ''
      stream {
          upstream backend_kube_proxy {
              server 10.0.1.100:6443;
              server 10.0.1.101:6443;
              server 10.0.1.102:6443;
              server 10.0.1.103:6443;
          }

          server {
              listen 6443;
              allow 10.0.0.0/24;  # WireGuard subnet
              deny all;

              proxy_pass backend_cluster;
              proxy_connect_timeout 1s;
              proxy_timeout 300s;
          }
      }
    '';
  };
}
