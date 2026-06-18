# ============================================================================
# Container App Job — Ephemeral Agent
# ============================================================================

module "aca_job" {
  source = "../azdo-ephemeral-agent-job"

  project                    = var.project
  resource_group_name        = module.resource_group.name
  location                   = var.location
  environment                = var.environment
  tenant_id                  = var.tenant_id
  instance                   = var.instance
  agent_type                 = var.agent_type
  cae_id                     = module.aca_env.cae_id
  acr_server                 = var.acr_server
  uami_id                    = module.agent_access.uami_id
  uami_client_id             = module.agent_access.uami_client_id
  azdo_org_url               = var.azdo_org_url
  azdo_pool_name             = module.agent_access.agent_pool_name
  azdo_pool_id               = tostring(module.agent_access.agent_pool_id)
  azdo_keda_pat              = var.azdo_keda_pat
  agent_image                = var.agent_image
  cpu                        = var.cpu
  memory                     = var.memory
  max_executions             = var.max_executions
  replica_timeout_in_seconds = var.replica_timeout_in_seconds

  depends_on = [module.aca_env, module.agent_access]
}
