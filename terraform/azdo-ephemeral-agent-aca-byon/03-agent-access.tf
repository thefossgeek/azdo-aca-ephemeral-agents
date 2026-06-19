# ============================================================================
# Azure DevOps Access — UAMI + Agent Pool + RBAC
# ============================================================================

module "agent_access" {
  source = "../azdo-ephemeral-agent-access"

  ado_project_name    = var.ado_project_name
  agent_pool_name     = var.agent_pool_name
  uami_name           = var.uami_name
  resource_group_name = local.rg.name
  location            = var.location
  tags                = var.tags
  role_assignments    = var.role_assignments

  depends_on = [module.resource_group, data.azurerm_resource_group.existing]
}
