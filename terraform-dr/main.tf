resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  name = "retail-store-dr-${random_string.suffix.result}"
  tags = {
    Environment = "dr"
    Project     = "retail-store"
    ManagedBy   = "terraform"
    CreatedBy   = "dr-user-mgmt"
  }
}

# Resource Group
resource "azurerm_resource_group" "dr" {
  name     = "retail-store-dr-rg"
  location = var.location
  tags     = local.tags
}

# Azure Container Registry
resource "azurerm_container_registry" "dr" {
  name                = "retailstoredr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.dr.name
  location            = azurerm_resource_group.dr.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.tags
}

# AKS Cluster — minimal config, no monitoring addons
resource "azurerm_kubernetes_cluster" "dr" {
  name                = local.name
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  dns_prefix          = "retailstoredr"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_DC2s_v3"  # 2 vCPU, 8GB — available in this subscription
    os_disk_size_gb     = 30
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 2
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  tags = local.tags
}

# Attach ACR to AKS so it can pull images without imagePullSecrets
resource "azurerm_role_assignment" "acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.dr.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.dr.id
  skip_service_principal_aad_check = true
}
