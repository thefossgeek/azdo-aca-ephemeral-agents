# ============================================================================
# Internal Naming Module
# ============================================================================
locals {
  vnet_name = "vnet-${var.workload}-${var.project}-${var.environment}-${var.location_code}-${var.instance}"
}

# ============================================================================
# Virtual Network
# ============================================================================

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = var.tags

  # Optional DDoS protection plan
  dynamic "ddos_protection_plan" {
    for_each = var.ddos_protection_plan_id != null ? [1] : []
    content {
      id     = var.ddos_protection_plan_id
      enable = true
    }
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false
    ignore_changes = [tags]
  }

}
