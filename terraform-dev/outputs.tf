# =============================================================================
# OUTPUTS - DEV ENVIRONMENT
# =============================================================================

output "cluster_name" {
  description = "Dev EKS cluster name"
  value       = module.dev_eks.cluster_name
}

output "cluster_endpoint" {
  description = "Dev EKS cluster endpoint"
  value       = module.dev_eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Command to configure kubectl for dev cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.dev_eks.cluster_name} --alias dev"
}

output "argocd_server_port_forward" {
  description = "Command to port-forward to dev ArgoCD"
  value       = "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8081:443 --context dev"
}

output "argocd_admin_password" {
  description = "Command to get dev ArgoCD admin password"
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive   = true
}

output "ingress_url" {
  description = "Command to get dev app URL"
  value       = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
