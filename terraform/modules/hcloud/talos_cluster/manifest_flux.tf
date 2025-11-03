resource "helm_release" "flux_system" {
  count            = var.control_plane_count > 0 ? 1 : 0
  name             = "flux"
  namespace        = "flux-system"
  create_namespace = true
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  version          = "2.17.1"

  values = [yamlencode({
    sourceController          = { create = true }
    helmController            = { create = true }
    kustomizeController       = { create = false }
    notificationController    = { create = false }
    imageAutomationController = { create = false }
    imageReflectionController = { create = false }
  })]

  depends_on = [data.http.talos_health]
}
