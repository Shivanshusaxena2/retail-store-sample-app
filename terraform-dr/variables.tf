# =============================================================================
# INPUT VARIABLES - DR ENVIRONMENT (AZURE)
# =============================================================================

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = "14652e0a-47e7-4d83-bc39-0947f8d35c58"
}

variable "azure_client_id" {
  description = "Azure Service Principal Client ID (dr-user-mgmt-sp)"
  type        = string
  default     = "a115e404-5cf5-48ba-b0a2-d7843d7a3232"
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
  default     = ""  # Set via TF_VAR_azure_client_secret env var
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  default     = "85e6742e-8945-4d4a-86f5-b0ce51e32e46"
}

variable "azure_location" {
  description = "Azure region for DR environment"
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
  default     = "retail-store-dr-rg"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "retail-store-dr"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.32"
}

variable "acr_name" {
  description = "Azure Container Registry name (must be globally unique, alphanumeric only)"
  type        = string
  default     = "retailstoredr"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dr"
}

variable "node_count" {
  description = "Number of nodes in DR cluster (keep low for cost)"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"  # 2 vCPU, 8GB RAM
}

variable "argocd_namespace" {
  description = "Namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

# AWS ECR details for image mirroring
variable "aws_account_id" {
  description = "AWS Account ID for ECR source"
  type        = string
  default     = "033484686218"
}

variable "aws_region" {
  description = "AWS region where ECR repos are"
  type        = string
  default     = "us-west-2"
}
