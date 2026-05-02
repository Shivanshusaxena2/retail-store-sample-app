variable "azure_subscription_id" {
  default = "14652e0a-47e7-4d83-bc39-0947f8d35c58"
}
variable "azure_client_id" {
  default = "a115e404-5cf5-48ba-b0a2-d7843d7a3232"
}
variable "azure_client_secret" {
  sensitive = true
  default   = ""
}
variable "azure_tenant_id" {
  default = "85e6742e-8945-4d4a-86f5-b0ce51e32e46"
}
variable "location" {
  default = "eastus"
}
variable "kubernetes_version" {
  default = "1.33"
}
variable "argocd_chart_version" {
  default = "5.51.6"
}
