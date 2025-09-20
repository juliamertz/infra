resource "helm_release" "metrics_server" {
  name      = "metrics-server"
  namespace = "kube-system"

  repository   = "https://kubernetes-sigs.github.io/metrics-server/"
  chart        = "metrics-server"
  version      = "3.13.0"

  values = [yamlencode({
    replicas = 1
    args = [
      "--kubelet-insecure-tls",
      "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
      "--metric-resolution=15s",
    ]
  })]

  depends_on = [data.http.talos_health]
}
