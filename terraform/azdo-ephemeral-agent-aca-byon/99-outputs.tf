# ============================================================================
# Resource Group
# ============================================================================

output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "Resource ID of the deployed resource group."
  value       = module.resource_group.id
}

# ============================================================================
# Virtual Network (existing — resolved via data source)
# ============================================================================

output "vnet_name" {
  description = "Name of the existing virtual network."
  value       = data.azurerm_virtual_network.vnet.name
}

output "vnet_id" {
  description = "Resource ID of the existing virtual network."
  value       = data.azurerm_virtual_network.vnet.id
}

output "infra_subnet_id" {
  description = "Resource ID of the infra subnet used by the Container App Environment."
  value       = data.azurerm_subnet.infra.id
}

# ============================================================================
# Azure DevOps Access
# ============================================================================

output "uami_id" {
  description = "Full resource ID of the User Assigned Managed Identity."
  value       = module.agent_access.uami_id
}

output "uami_client_id" {
  description = "Client ID of the managed identity (AZURE_CLIENT_ID)."
  value       = module.agent_access.uami_client_id
}

output "uami_principal_id" {
  description = "Object ID of the managed identity for RBAC assignments."
  value       = module.agent_access.uami_principal_id
}

output "agent_pool_name" {
  description = "Azure DevOps agent pool name."
  value       = module.agent_access.agent_pool_name
}

output "agent_pool_id" {
  description = "Numeric Azure DevOps agent pool ID."
  value       = module.agent_access.agent_pool_id
}

output "agent_queue_id" {
  description = "Project-level agent queue ID — pass to azdo-pipeline-permissions module."
  value       = module.agent_access.agent_queue_id
}

output "project_id" {
  description = "AzDO project ID — pass to azdo-pipeline-permissions module."
  value       = module.agent_access.project_id
}

# ============================================================================
# Container App Environment
# ============================================================================

output "cae_id" {
  description = "Resource ID of the Container App Environment."
  value       = module.aca_env.cae_id
}

output "cae_name" {
  description = "Name of the Container App Environment."
  value       = module.aca_env.cae_name
}

# ============================================================================
# Container App Job
# ============================================================================

output "job_name" {
  description = "Name of the Container App Job. Use with: az containerapp job start -n <job_name> -g <rg>"
  value       = module.aca_job.job_name
}
