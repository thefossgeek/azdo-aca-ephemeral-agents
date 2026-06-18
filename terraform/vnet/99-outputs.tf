output "vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "ID of the virtual network"
}

output "vnet_name" {
  value       = azurerm_virtual_network.vnet.name
  description = "Name of the virtual network"
}

output "vnet_address_space" {
  value       = azurerm_virtual_network.vnet.address_space
  description = "Address space of the virtual network"
}

# ============================================================================
# Subnet Outputs
# ============================================================================

# Subnet IDs map - most commonly used
output "subnet_ids" {
  description = "Map of subnet IDs by subnet name"
  value       = { for k, v in azurerm_subnet.subnet : k => v.id }
}

# Subnet names map
output "subnet_names" {
  description = "Map of subnet names"
  value       = { for k, v in azurerm_subnet.subnet : k => v.name }
}

# Subnet address prefixes map
output "subnet_address_prefixes" {
  description = "Map of subnet address prefixes by subnet name"
  value       = { for k, v in azurerm_subnet.subnet : k => v.address_prefixes }
}

# List of all subnet IDs
output "subnet_ids_list" {
  description = "List of all subnet IDs"
  value       = [for v in azurerm_subnet.subnet : v.id]
}

# List of all subnet names
output "subnet_names_list" {
  description = "List of all subnet names"
  value       = [for v in azurerm_subnet.subnet : v.name]
}
