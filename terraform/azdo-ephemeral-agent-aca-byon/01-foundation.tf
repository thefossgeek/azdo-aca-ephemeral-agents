# ============================================================================
# Resource Group
# ============================================================================

module "resource_group" {
  count  = var.create_resource_group ? 1 : 0
  source = "../resource-group"

  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  enable_lock         = var.enable_rg_lock
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  rg = {
    name = var.resource_group_name
    id   = var.create_resource_group ? module.resource_group[0].id : data.azurerm_resource_group.existing[0].id
  }
}
