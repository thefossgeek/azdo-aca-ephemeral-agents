# ============================================================================
# Container App Environment
# ============================================================================

module "aca_env" {
  source = "../azdo-ephemeral-agent-env"

  project             = var.project
  resource_group_name = module.resource_group.name
  location            = var.location
  environment         = var.environment
  location_code       = var.location_code
  instance            = var.instance
  tags                = var.tags
  infra_subnet_id     = module.vnet.subnet_ids[var.infra_subnet_name]
  create_law          = var.create_law
  existing_law_id     = var.existing_law_id

  depends_on = [module.vnet]
}
