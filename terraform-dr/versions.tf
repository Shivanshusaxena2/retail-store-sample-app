terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0, < 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.dr.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.dr.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.dr.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.dr.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.dr.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.dr.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.dr.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.dr.kube_config[0].cluster_ca_certificate)
  load_config_file       = false
}
