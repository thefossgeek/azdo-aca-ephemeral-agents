# ============================================================================
# UDR — Hub Firewall Routing (optional)
#
# Disabled by default (enable_udr = false). When enabled, a route table is
# created in the VNET resource group (same RG as the vnet/subnets) so that
# Azure can associate it with the existing subnets. Only the subnets listed
# in udr_subnet_names are associated — all other subnets in the vnet are
# unaffected.
#
# The route table location is derived from the existing vnet so it is always
# co-located, regardless of where the agent resources are deployed.
#
# Required permission: Network Contributor on vnet_resource_group_name.
#
# To enable:  set enable_udr = true and hub_firewall_ip in terragrunt.hcl
# To disable: set enable_udr = false (module is not called at all)
# ============================================================================

module "udr" {
  count  = var.enable_udr ? 1 : 0
  source = "../udr"

  name                = "rt-eph-agent-${var.environment}-${var.location_code}-${var.instance}"
  resource_group_name = local.vnet_rg
  location            = data.azurerm_virtual_network.vnet.location
  tags                = var.tags
  hub_firewall_ip     = var.hub_firewall_ip

  # Only the named subnets receive the route table association.
  # Other subnets in the vnet are not touched.
  subnet_ids = {
    for name, subnet in data.azurerm_subnet.udr_subnets : name => subnet.id
  }
}
