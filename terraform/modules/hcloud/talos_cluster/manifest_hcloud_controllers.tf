resource "kubectl_manifest" "hetzner_namespace" {
  count = var.control_plane_count > 0 ? 1 : 0
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
  count = var.control_plane_count > 0 ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name = "hcloud"
      namespace = "hetzner-system"
    }
    data = {
      network = base64encode(hcloud_network.this.id)
      token = base64encode(var.hcloud_token)
    }
  })
  apply_only = true
  depends_on = [data.http.talos_health]
}

resource "helm_release" "hcloud_controller" {
  name      = "hcloud-cloud-controller-manager"
  namespace = "hetzner-system"

  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-cloud-controller-manager"
  version      = var.hcloud_ccm_version

  values = [yamlencode({
    networking = {
      enabled = true
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

  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-csi"
  version      = "2.17.0"

  values = [yamlencode({
    controller = {
      replicaCount = 2
    }
  })]

  depends_on = [
    data.http.talos_health,
    kubectl_manifest.hetzner_namespace,
    kubectl_manifest.hetzner_token_secret
  ]
}
