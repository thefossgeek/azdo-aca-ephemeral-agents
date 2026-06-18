output "cae_id" {
  description = "Resource ID of the Container App Environment — passed to each aca-agent-job module."
  value       = azurerm_container_app_environment.this.id
}

output "cae_name" {
  description = "Name of the Container App Environment."
  value       = azurerm_container_app_environment.this.name
}
