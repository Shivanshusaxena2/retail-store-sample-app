# =============================================================================
# EKS ADD-ONS - DEV ENVIRONMENT
# =============================================================================

module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.dev_eks.cluster_name
  cluster_endpoint  = module.dev_eks.cluster_endpoint
  cluster_version   = module.dev_eks.cluster_version
  oidc_provider_arn = module.dev_eks.oidc_provider_arn

  enable_cert_manager = true
  cert_manager = {
    most_recent = true
    namespace   = "cert-manager"
  }

  enable_ingress_nginx = true
  ingress_nginx = {
    most_recent = true
    namespace   = "ingress-nginx"
    set = [
      { name = "controller.service.type",                          value = "LoadBalancer" },
      { name = "controller.service.externalTrafficPolicy",         value = "Local" },
      { name = "controller.resources.requests.cpu",                value = "100m" },
      { name = "controller.resources.requests.memory",             value = "128Mi" },
      { name = "controller.resources.limits.cpu",                  value = "200m" },
      { name = "controller.resources.limits.memory",               value = "256Mi" }
    ]
    set_sensitive = [
      { name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme",              value = "internet-facing" },
      { name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type",                value = "nlb" },
      { name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type",     value = "instance" },
      { name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-path",   value = "/healthz" },
      { name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-port",   value = "10254" },
      { name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-protocol", value = "HTTP" }
    ]
  }

  depends_on = [module.dev_eks]
}
