output "uami_id" {
  description = "Full Azure resource ID of the User Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "uami_client_id" {
  description = "Client ID (Application ID) of the managed identity — used for AZURE_CLIENT_ID and KEDA auth."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "uami_principal_id" {
  description = "Object ID (principal ID) of the managed identity — used for RBAC role assignments."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "agent_pool_name" {
  description = "Name of the Azure DevOps agent pool — used for AZP_POOL env var."
  value       = azuredevops_agent_pool.this.name
}

output "agent_pool_id" {
  description = "Numeric ID of the Azure DevOps agent pool — used by KEDA scaler poolID."
  value       = azuredevops_agent_pool.this.id
}

output "agent_queue_id" {
  description = "ID of the project-level agent queue — used for pipeline authorization."
  value       = azuredevops_agent_queue.this.id
}

output "project_id" {
  description = "AzDO project ID — used for scoping pipeline authorization resources."
  value       = data.azuredevops_project.this.id
}
