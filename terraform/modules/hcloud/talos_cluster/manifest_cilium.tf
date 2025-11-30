resource "helm_release" "cilium" {
  count      = local.total_control_plane_count > 0 ? 1 : 0
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.18.4"

  values = [jsonencode({
    operator = {
      replicas = 2
      prometheus = {
        serviceMonitor = {
          enabled = false
        }
      }
    }
    ipam = {
      mode = "kubernetes"
    }
    routingMode           = "native"
    ipv4NativeRoutingCIDR = "10.0.16.0/20"
    kubeProxyReplacement  = true
    bpf = {
      masquerade = false
    }
    loadBalancer = {
      acceleration = "native"
    }
    encryption = {
      enabled = false
      type    = "wireguard"
    }
    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN",
          "KILL",
          "NET_ADMIN",
          "NET_RAW",
          "IPC_LOCK",
          "SYS_ADMIN",
          "SYS_RESOURCE",
          "DAC_OVERRIDE",
          "FOWNER",
          "SETGID",
          "SETUID"
        ]
        cleanCiliumState = [
          "NET_ADMIN",
          "SYS_ADMIN",
          "SYS_RESOURCE"
        ]
      }
    }
    socketLB = {
      hostNamespaceOnly = true
    }
    cgroup = {
      autoMount = {
        enabled = false
      }
      hostRoot = "/sys/fs/cgroup"
    }
    k8sServiceHost = "127.0.0.1"
    k8sServicePort = 7445
    hubble = {
      enabled = false
    }
    prometheus = {
      serviceMonitor = {
        enabled        = false
        trustCRDsExist = false
      }
    }
  })]

  depends_on = [data.http.talos_health]
}


data "helm_template" "prometheus_operator_crds" {
  count        = var.deploy_prometheus_operator_crds ? 1 : 0
  chart        = "prometheus-operator-crds"
  name         = "prometheus-operator-crds"
  repository   = "https://prometheus-community.github.io/helm-charts"
  kube_version = var.kubernetes_version
}

data "kubectl_file_documents" "prometheus_operator_crds" {
  count   = var.deploy_prometheus_operator_crds ? 1 : 0
  content = data.helm_template.prometheus_operator_crds[0].manifest
}

resource "kubectl_manifest" "apply_prometheus_operator_crds" {
  for_each          = local.total_control_plane_count > 0 && var.deploy_prometheus_operator_crds ? data.kubectl_file_documents.prometheus_operator_crds[0].manifests : {}
  yaml_body         = each.value
  server_side_apply = true
  apply_only        = true
  depends_on        = [data.http.talos_health]
}
