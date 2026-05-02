output "cluster_name" {
  value = azurerm_kubernetes_cluster.dr.name
}
output "resource_group" {
  value = azurerm_resource_group.dr.name
}
output "acr_login_server" {
  value = azurerm_container_registry.dr.login_server
}
output "acr_name" {
  value = azurerm_container_registry.dr.name
}
output "acr_admin_username" {
  value     = azurerm_container_registry.dr.admin_username
  sensitive = true
}
output "acr_admin_password" {
  value     = azurerm_container_registry.dr.admin_password
  sensitive = true
}
output "configure_kubectl" {
  value = "az aks get-credentials --resource-group retail-store-dr-rg --name ${azurerm_kubernetes_cluster.dr.name} --context dr"
}
output "argocd_port_forward" {
  value = "kubectl port-forward svc/argocd-server -n argocd 8082:443 --context dr"
}
