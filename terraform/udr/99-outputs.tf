output "route_table_id" {
  description = "Resource ID of the route table."
  value       = azurerm_route_table.this.id
}

output "route_table_name" {
  description = "Name of the route table."
  value       = azurerm_route_table.this.name
}
