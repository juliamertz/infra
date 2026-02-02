locals {
  # Define a dummy worker entry for when count is 0
  dummy_workers = local.total_worker_count == 0 ? [{
    index               = 0
    name                = "dummy-worker-0"
    server_type         = "cx11"
    image_id            = null
    ipv4_public         = "0.0.0.0"
    ipv6_public         = null
    ipv6_public_subnet  = null
    ipv4_private        = cidrhost(local.node_ipv4_cidr, 200)
    labels              = {}
    taints              = []
    node_group_index    = 0
    node_in_group_index = 0
  }] : []

  # Combine real and dummy workers
  merged_workers = concat(local.workers, local.dummy_workers)

  # Base kubelet config shared by all workers
  base_kubelet_config = {
    extraArgs = merge(
      {
        "cloud-provider"             = "external"
        "rotate-server-certificates" = true
      },
      var.kubelet_extra_args
    )
    extraConfig = {
      imageGCHighThresholdPercent = 60
      imageGCLowThresholdPercent = 50
    }
    nodeIP = {
      validSubnets = [
        local.node_ipv4_cidr
      ]
    }
  }

  # Base machine config shared by all workers
  base_machine_config = {
    install = {
      image = "ghcr.io/siderolabs/installer:${var.talos_version}"
      extraKernelArgs = [
        "ipv6.disable=${var.enable_ipv6 ? 0 : 1}",
      ]
    }
    certSANs = local.cert_SANs
    network = {
      extraHostEntries = local.extra_host_entries
      kubespan = {
        enabled                     = var.enable_kube_span
        advertiseKubernetesNetworks = false
        mtu                         = 1370
      }
    }
    kernel = {
      modules = var.kernel_modules_to_load
    }
    sysctls = merge(
      {
        "net.core.somaxconn"          = "65535"
        "net.core.netdev_max_backlog" = "4096"
      },
      var.sysctls_extra_args
    )
    features = {
      hostDNS = {
        enabled              = true
        forwardKubeDNSToHost = true
        resolveMemberNames   = true
      }
    }
    time = {
      servers = [
        "ntp1.hetzner.de",
        "ntp2.hetzner.com",
        "ntp3.hetzner.net",
        "time.cloudflare.com"
      ]
    }
    registries = var.registries
  }

  # Base cluster config shared by all workers
  base_cluster_config = {
    network = {
      dnsDomain = var.cluster_domain
      podSubnets = [
        local.pod_ipv4_cidr
      ]
      serviceSubnets = [
        local.service_ipv4_cidr
      ]
      cni = {
        name = "none"
      }
    }
  }

  # Generate YAML for all (real or dummy) workers
  worker_yaml = {
    for worker in local.merged_workers : worker.name => {
      machine = merge(
        local.base_machine_config,
        {
          kubelet = merge(
            local.base_kubelet_config,
            length(worker.taints) > 0 ? {
              extraConfig = {
                registerWithTaints = [
                  for taint in worker.taints : {
                    key    = taint.key
                    value  = taint.value
                    effect = taint.effect
                  }
                ]
              }
            } : {}
          )
          nodeLabels = worker.labels
        }
      )
      cluster = local.base_cluster_config
    }
  }

  autoscale_worker_labels = {
    "node.kubernetes.io/role" = "autoscaler-node"
    "hcloud/node-group"       = "workers"
  }
  autoscale_worker_taints = [
    {
      key    = "node.kubernetes.io/role"
      value  = "autoscaler-node"
      effect = "NoExecute"
    }
  ]

  autoscale_worker_yaml = {
    machine = merge(
      local.base_machine_config,
      {
        kubelet = merge(
          local.base_kubelet_config,
          {
            extraConfig = {
              registerWithTaints = [
                for taint in local.autoscale_worker_taints : {
                  key    = taint.key
                  value  = taint.value
                  effect = taint.effect
                }
              ]
            }
          }
        )
        nodeLabels = local.autoscale_worker_labels
      }
    )
    cluster = local.base_cluster_config
  }

  gameserver_worker_labels = {
    "node.kubernetes.io/role" = "gameserver-node"
    "hcloud/node-group"       = "gameserver-node"
  }
  gameserver_worker_taints = [
    {
      key    = "node.kubernetes.io/role"
      value  = "gameserver-node"
      effect = "NoExecute"
    }
  ]

  gameserver_worker_yaml = {
    machine = merge(
      local.base_machine_config,
      {
        kubelet = merge(
          local.base_kubelet_config,
          {
            extraConfig = {
              registerWithTaints = [
                for taint in local.gameserver_worker_taints : {
                  key    = taint.key
                  value  = taint.value
                  effect = taint.effect
                }
              ]
            }
          }
        )
        nodeLabels = local.gameserver_worker_labels
      }
    )
    cluster = local.base_cluster_config
  }
}
