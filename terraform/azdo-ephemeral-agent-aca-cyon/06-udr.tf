# ============================================================================
# UDR — Hub Firewall Routing (optional)
#
# Disabled by default (enable_udr = false). When enabled, a route table is
# created and associated only with the subnets listed in udr_subnet_names,
# routing all their egress through the hub FortiGate firewall.
#
# To enable:  set enable_udr = true and hub_firewall_ip in terragrunt.hcl
# To disable: set enable_udr = false (module is not called at all)
# ============================================================================

module "udr" {
  count  = var.enable_udr ? 1 : 0
  source = "../udr"

  name                = "rt-${var.workload}-${var.environment}-${var.location_code}-${var.instance}"
  resource_group_name = module.resource_group.name
  location            = var.location
  tags                = var.tags
  hub_firewall_ip     = var.hub_firewall_ip

  # Filter the vnet's subnet_ids map to only the subnets that need UDR.
  # Best practice: list only the agent subnet(s), not all subnets.
  subnet_ids = {
    for name, id in module.vnet.subnet_ids :
    name => id
    if contains(var.udr_subnet_names, name)
  }

  depends_on = [module.vnet]
}
