# ============================================================================
# Container App Environment
# ============================================================================

module "aca_env" {
  source = "../azdo-ephemeral-agent-env"

  project             = var.project
  resource_group_name = local.rg.name
  location            = var.location
  environment         = var.environment
  location_code       = var.location_code
  instance            = var.instance
  tags                = var.tags
  infra_subnet_id     = data.azurerm_subnet.infra.id
  create_law          = var.create_law
  existing_law_id     = var.existing_law_id

  depends_on = [module.resource_group, data.azurerm_resource_group.existing, module.agent_access]
}
