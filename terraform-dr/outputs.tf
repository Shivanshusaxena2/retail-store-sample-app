# =============================================================================
# OUTPUTS - DR ENVIRONMENT (AZURE)
# =============================================================================

output "resource_group_name" {
  description = "Azure Resource Group name"
  value       = azurerm_resource_group.dr.name
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.aks_name
}

output "acr_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.dr.name
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.dr.login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = azurerm_container_registry.dr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "ACR admin password"
  value       = azurerm_container_registry.dr.admin_password
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl for DR cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.dr.name} --name ${module.aks.aks_name} --context dr"
}

output "argocd_port_forward" {
  description = "Command to port-forward ArgoCD on DR"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8082:443 --context dr"
}

output "argocd_password" {
  description = "ArgoCD admin password"
  value       = "admin@123"
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.dr.id
}
