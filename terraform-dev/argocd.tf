# =============================================================================
# ARGOCD - DEV ENVIRONMENT
# =============================================================================

resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on = [
    module.dev_eks,
    module.eks_addons
  ]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true
  timeout          = 600
  wait             = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = true
        }
        # Set admin password to admin@123 (bcrypt hash)
        secret = {
          argocdServerAdminPassword      = "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW1/6SpIykYSC.pLi"
          argocdServerAdminPasswordMtime = "2026-01-01T00:00:00Z"
        }
      }
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = false
        }
      }
      controller = {
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
      }
      repoServer = {
        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }
      redis = {
        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "200m", memory = "128Mi" }
        }
      }
    })
  ]

  depends_on = [time_sleep.wait_for_cluster]
}

resource "kubectl_manifest" "argocd_projects" {
  for_each   = fileset("${path.module}/../argocd-dev/projects", "*.yaml")
  yaml_body  = file("${path.module}/../argocd-dev/projects/${each.value}")
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_apps" {
  for_each   = fileset("${path.module}/../argocd-dev/applications", "*.yaml")
  yaml_body  = file("${path.module}/../argocd-dev/applications/${each.value}")
  depends_on = [kubectl_manifest.argocd_projects]
}
