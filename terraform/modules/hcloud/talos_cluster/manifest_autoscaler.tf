locals {
  cluster_config = {
    imagesForArch = { // These should be the same format as HCLOUD_IMAGE
      arm64 = "",
      amd64 = ""
    }
    # "defaultSubnetIPRange": "10.0.0.0/16", // Optional, if not set the hetzner cloud default will be used - make sure this subnet exists within you private network and to use the cidr notation
    nodeConfigs = {
      workers = {      // This equals the pool name. Required for each pool that you have
        cloudInit = "" // HCLOUD_CLOUD_INIT make sure it isn't base64 encoded twice ;]
        labels = {
          "node.kubernetes.io/role" = "autoscaler-node"
        }
        taints = [{
            key    = "node.kubernetes.io/role"
            value  = "autoscaler-node"
            effect = "NoExecute"
        }]
        # "subnetIPRange": "10.0.0.0/24" // Optional, if not set the defaultSubnetIPRange will be used - make sure this subnet exists within you private network and to use the cidr notation
      }
    }
  }
}

resource "helm_release" "autoscaler" {
  count      = local.total_control_plane_count > 0 ? 1 : 0
  name       = "hcloud-autoscaler"
  namespace  = "hetzner-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.52.1"

  values = [yamlencode({
    cloudProvider = "hetzner"
    fullnameOverride = "hcloud-cluster-autoscaler"
    autoDiscovery = { clusterName = "cluster.local" }
    extraEnvSecrets = {
      HCLOUD_TOKEN = {
        name = "hcloud"
        key  = "token"
      }
    }
    extraEnv = {
      HCLOUD_CLUSTER_CONFIG = base64encode(jsonencode(local.cluster_config))
      HCLOUD_NETWORK = hcloud_network.this.id
    }
    autoscalingGroups = [{
      name = "workers"
      instanceType = "cax11"
      minSize = 0
      maxSize = 3
    }]
  })]

  depends_on = [data.http.talos_health]
}
