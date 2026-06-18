# ============================================================================
# Networking — data sources only (vnet and subnets already exist)
# ============================================================================

locals {
  # When vnet lives in a different RG (hub/spoke), set vnet_resource_group_name
  # explicitly. Defaults to the agent resource group for single-RG setups.
  vnet_rg = coalesce(var.vnet_resource_group_name, var.resource_group_name)
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = local.vnet_rg
}

data "azurerm_subnet" "infra" {
  name                 = var.infra_subnet_name
  resource_group_name  = local.vnet_rg
  virtual_network_name = data.azurerm_virtual_network.vnet.name
}

# Fetched only when enable_udr = true and udr_subnet_names is non-empty.
# These are the subnets that will have the route table associated.
data "azurerm_subnet" "udr_subnets" {
  for_each             = var.enable_udr ? toset(var.udr_subnet_names) : toset([])
  name                 = each.value
  resource_group_name  = local.vnet_rg
  virtual_network_name = data.azurerm_virtual_network.vnet.name
}
