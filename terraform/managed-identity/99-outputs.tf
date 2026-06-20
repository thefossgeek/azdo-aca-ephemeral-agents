output "mi_id" {
  description = "Full Azure resource ID of the managed identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "mi_client_id" {
  description = "Client ID — use with: az login --identity --username <client_id>"
  value       = azurerm_user_assigned_identity.this.client_id
}

output "mi_principal_id" {
  description = "Object ID — use for additional RBAC assignments outside this module."
  value       = azurerm_user_assigned_identity.this.principal_id
}
