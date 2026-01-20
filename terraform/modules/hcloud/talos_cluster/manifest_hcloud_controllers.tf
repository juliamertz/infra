resource "kubectl_manifest" "hetzner_namespace" {
  count = 1
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "hetzner-system"
      labels = {
        "pod-security.kubernetes.io/enforce" = "privileged"
        "pod-security.kubernetes.io/audit"   = "privileged"
        "pod-security.kubernetes.io/warn"    = "privileged"
      }
    }
  })
  apply_only = true
  depends_on = [data.http.talos_health]
}

resource "kubectl_manifest" "hetzner_token_secret" {
  count = 1
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "hcloud"
      namespace = "hetzner-system"
    }
    data = {
      network = base64encode(hcloud_network.this.id)
      token   = base64encode(var.hcloud_token)
    }
  })
  apply_only = true
  depends_on = [data.http.talos_health]
}

resource "helm_release" "hcloud_controller" {
  name      = "hcloud-cloud-controller-manager"
  namespace = "hetzner-system"

  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-cloud-controller-manager"
  version    = "1.29.1"

  values = [yamlencode({
    networking = {
      enabled     = true
      clusterCIDR = local.pod_ipv4_cidr
    }
  })]

  depends_on = [
    data.http.talos_health,
    kubectl_manifest.hetzner_namespace,
    kubectl_manifest.hetzner_token_secret,
  ]
}

resource "helm_release" "hcloud_csi" {
  name      = "hcloud-csi"
  namespace = "hetzner-system"

  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-csi"
  version    = "2.18.3"

  values = [yamlencode({
    storageClasses = [{
      name                = "hcloud-volumes"
      defaultStorageClass = false
      reclaimPolicy       = "Delete"
    }]

    controller = {
      replicaCount                = 2
      hcloudVolumeDefaultLocation = "nbg1"
      volumeExtraLabels = {
        env     = "production"
        team    = "devops"
        cluster = "mycluster"
      }
      priorityClassName = "system-cluster-critical"
      resources = {
        csiAttacher = {
          limits = {
            memory = "80Mi"
            cpu    = "50m"
          }
          requests = {
            memory = "20Mi"
            cpu    = "10m"
          }
        }
        csiResizer = {
          limits = {
            memory = "80Mi"
            cpu    = "50m"
          }
          requests = {
            memory = "20Mi"
            cpu    = "10m"
          }
        }
        csiProvisioner = {
          limits = {
            memory = "80Mi"
            cpu    = "50m"
          }
          requests = {
            memory = "20Mi"
            cpu    = "10m"
          }
        }
        livenessProbe = {
          limits = {
            memory = "80Mi"
            cpu    = "50m"
          }
          requests = {
            memory = "20Mi"
            cpu    = "10m"
          }
        }
        hcloudCSIDriver = {
          limits = {
            memory = "80Mi"
            cpu    = "100m"
          }
          requests = {
            memory = "40Mi"
            cpu    = "10m"
          }
        }
      }
      # affinity = {
      #   podAntiAffinity = {
      #     requiredDuringSchedulingIgnoredDuringExecution = [
      #       {
      #         labelSelector = {
      #           matchExpressions = [
      #             {
      #               key      = "csi-hcloud"
      #               operator = "In"
      #               values   = ["controller"]
      #             }
      #           ]
      #         }
      #         topologyKey = "kubernetes.io/hostname"
      #       }
      #     ]
      #   }
      # }
    }

    node = {
      priorityClassName = "system-node-critical"
      resources = {
        csiNodeDriverRegistrar = {
          limits = {
            memory = "40Mi"
            cpu    = "50m"
          }
          requests = {
            memory = "20Mi"
            cpu    = "10m"
          }
        }
        livenessProbe = {
          limits = {
            memory = "40Mi"
            cpu    = "50m"
          }
          requests = {
            memory = "20Mi"
            cpu    = "10m"
          }
        }
        hcloudCSIDriver = {
          limits = {
            memory = "80Mi"
            cpu    = "100m"
          }
          requests = {
            memory = "40Mi"
            cpu    = "10m"
          }
        }
      }
      hostNetwork = true
      # affinity = {
      #   nodeAffinity = {
      #     requiredDuringSchedulingIgnoredDuringExecution = {
      #       nodeSelectorTerms = [
      #         {
      #           matchExpressions = [
      #             {
      #               key      = "node-role.kubernetes.io/control-plane"
      #               operator = "NotIn"
      #               values   = [""]
      #             }
      #           ]
      #         }
      #       ]
      #     }
      #   }
      # }
    }

    metrics = {
      enabled = true
    }

  })]

  depends_on = [
    data.http.talos_health,
    kubectl_manifest.hetzner_namespace,
    kubectl_manifest.hetzner_token_secret
  ]
}
