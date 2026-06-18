variable "location" {
  description = "Azure region where the route table will be created."
  type        = string
}

variable "tags" {
  description = "Tags to apply to the route table."
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "Resource group where the route table will be created."
  type        = string
}

variable "name" {
  description = "Name of the route table resource."
  type        = string
}

variable "hub_firewall_ip" {
  description = "Private IP of the hub firewall (FortiGate NVA). All traffic is routed here as a VirtualAppliance next hop."
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet IDs to associate with the route table (key = subnet name, value = subnet resource ID)."
  type        = map(string)
}
