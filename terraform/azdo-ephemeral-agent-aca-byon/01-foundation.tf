# ============================================================================
# Resource Group
# ============================================================================

module "resource_group" {
  source = "../resource-group"

  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  enable_lock         = var.enable_rg_lock
}
