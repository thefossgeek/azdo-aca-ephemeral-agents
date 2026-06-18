output "job_name" {
  description = "Name of the Container App Job — use for monitoring dashboards and manual trigger via az CLI."
  value       = azurerm_container_app_job.this.name
}
