# ============================================================================
# Virtual Network
# ============================================================================

module "vnet" {
  source = "../vnet"

  resource_group_name     = module.resource_group.name
  location                = var.location
  environment             = var.environment
  project                 = var.project
  location_code           = var.location_code
  instance                = var.instance
  tags                    = var.tags
  workload                = var.workload
  address_space           = var.address_space
  dns_servers             = var.dns_servers
  ddos_protection_plan_id = var.ddos_protection_plan_id
  subnets                 = var.subnets
  enable_resource_lock    = var.enable_vnet_lock

  depends_on = [module.resource_group]
}
