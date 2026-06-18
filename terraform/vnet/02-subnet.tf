# ============================================================================
# Subnet Resources - Creates multiple subnets
# ============================================================================

resource "azurerm_subnet" "subnet" {
  for_each = { for subnet in var.subnets : subnet.name => subnet }

  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefixes

  # Optional service endpoints
  service_endpoints = each.value.service_endpoints

  # Optional delegation for specific Azure services
  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }

  # Private endpoint network policies
  private_endpoint_network_policies             = each.value.private_endpoint_network_policies
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [azurerm_virtual_network.vnet]
}
