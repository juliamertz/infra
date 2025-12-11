data "talos_machine_configuration" "autoscaler_node" {
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = concat([yamlencode(local.autoscale_worker_yaml)], var.talos_worker_extra_config_patches)
  docs               = false
  examples           = false
}

data "talos_machine_configuration" "gameserver_node" {
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = concat([yamlencode(local.gameserver_worker_yaml)], var.talos_worker_extra_config_patches)
  docs               = false
  examples           = false
}

resource "helm_release" "autoscaler" {
  count      = local.total_control_plane_count > 0 ? 1 : 0
  name       = "hcloud-autoscaler"
  namespace  = "hetzner-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.54.0"
  values = [yamlencode({
    cloudProvider    = "hetzner"
    fullnameOverride = "hcloud-cluster-autoscaler"
    autoDiscovery    = { clusterName = "cluster.local" }
    extraEnv = {
      HCLOUD_CLUSTER_CONFIG = base64encode(jsonencode({
        imagesForArch = {
          arm64 = tostring(data.hcloud_image.arm[0].id)
          amd64 = tostring(data.hcloud_image.x86[0].id)
        }
        nodeConfigs = {
          nodes-green = {
            cloudInit = data.talos_machine_configuration.autoscaler_node.machine_configuration
            labels = local.autoscale_worker_labels
            taints = local.autoscale_worker_taints
          }
          gameserver-node = {
            cloudInit = data.talos_machine_configuration.gameserver_node.machine_configuration
            labels = local.gameserver_worker_labels
            taints = local.gameserver_worker_taints
          }
        }
      }))
      HCLOUD_NETWORK = hcloud_network.this.id
      HCLOUD_FIREWALL = hcloud_firewall.valheim_firewall.id
    }
    autoscalingGroups = [
      {
        name         = "nodes-green"
        region       = "nbg1"
        instanceType = "cax11"
        minSize      = 0
        maxSize      = 3
      },
      {
        name         = "gameserver-node"
        region       = "nbg1"
        instanceType = "cx23"
        minSize      = 0
        maxSize      = 1
      }
    ]
    extraEnvSecrets = {
      HCLOUD_TOKEN = {
        name = "hcloud"
        key  = "token"
      }
    }
  })]
  depends_on = [
    data.http.talos_health
  ]
}
