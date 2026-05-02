# =============================================================================
# MAIN INFRASTRUCTURE - DR ENVIRONMENT (AZURE)
# =============================================================================

# Resource Group
resource "azurerm_resource_group" "dr" {
  name     = var.resource_group_name
  location = var.azure_location
  tags     = local.common_tags
}

# =============================================================================
# VIRTUAL NETWORK
# =============================================================================

resource "azurerm_virtual_network" "dr" {
  name                = "${local.cluster_name}-vnet"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  address_space       = ["10.2.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.dr.name
  virtual_network_name = azurerm_virtual_network.dr.name
  address_prefixes     = ["10.2.1.0/24"]
}

# =============================================================================
# AZURE CONTAINER REGISTRY (ACR)
# Mirror of AWS ECR for DR images
# =============================================================================

resource "azurerm_container_registry" "dr" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.dr.name
  location            = azurerm_resource_group.dr.location
  sku                 = "Standard"
  admin_enabled       = true
  tags                = local.common_tags
}

# =============================================================================
# AKS CLUSTER
# =============================================================================

module "aks" {
  source  = "Azure/aks/azurerm"
  version = "~> 9.0"

  resource_group_name = azurerm_resource_group.dr.name
  location            = azurerm_resource_group.dr.location
  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  prefix              = "dr"

  # Node pool configuration
  agents_count    = var.node_count
  agents_size     = var.node_vm_size
  agents_min_count = 1
  agents_max_count = 4
  enable_auto_scaling = true

  # Network
  vnet_subnet_id = azurerm_subnet.aks.id
  network_plugin = "azure"
  network_policy = "azure"

  # Identity
  identity_type = "SystemAssigned"

  # Attach ACR to AKS so it can pull images without imagePullSecrets
  attached_acr_id_map = {
    dr_acr = azurerm_container_registry.dr.id
  }

  # OIDC + Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = local.common_tags

  depends_on = [azurerm_resource_group.dr]
}
