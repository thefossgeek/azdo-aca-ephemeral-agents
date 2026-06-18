variable "location" {
  description = "Azure region where the ACA environment will be created."
  type        = string
}

variable "environment" {
  description = "Environment name used in resource naming (e.g. dev, staging, prod)."
  type        = string
}

variable "location_code" {
  description = "Short location code used in resource naming (e.g. euw for West Europe)."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "Resource group where the ACA environment will be created."
  type        = string
}

variable "project" {
  description = "Short project code for resource names (e.g. spai)."
  type        = string
}

variable "instance" {
  description = "Zero-padded instance number to distinguish multiple environments (e.g. 001)."
  type        = string
  default     = "001"
}

variable "infra_subnet_id" {
  description = "Subnet ID delegated to the ACA environment for internal infrastructure."
  type        = string
}

variable "create_law" {
  description = "Create a new Log Analytics Workspace. Set false to reuse an existing one via existing_law_id."
  type        = bool
  default     = true
}

variable "existing_law_id" {
  description = "Resource ID of an existing Log Analytics Workspace. Required when create_law = false."
  type        = string
  default     = null
}

