# ============================================================================
# Common Variables
# ============================================================================

variable "location" {
  type        = string
  description = "Azure region where the virtual network will be created."
}

variable "environment" {
  type        = string
  description = "Environment name used in resource naming (e.g. dev, staging, prod)."
}

variable "product" {
  type        = string
  description = "Product code used in resource naming."
}

variable "location_code" {
  type        = string
  description = "Short location code used in resource naming (e.g. euw for West Europe)."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}

# ============================================================================
# Naming Variables (for internal naming module)
# ============================================================================

variable "workload" {
  type        = string
  description = "Workload or application name"
}

variable "instance" {
  type        = string
  description = "Instance number (e.g., '001', '002')"
  default     = "001"
}

# ============================================================================
# Resource Lock (Optional)
# ============================================================================

variable "enable_resource_lock" {
  type        = bool
  description = "Enable resource lock to prevent accidental deletion or modification"
  default     = false
}

variable "lock_level" {
  type        = string
  description = "Lock level: CanNotDelete (prevent deletion) or ReadOnly (prevent changes)"
  default     = "CanNotDelete"

  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.lock_level)
    error_message = "Lock level must be 'CanNotDelete' or 'ReadOnly'"
  }
}

variable "lock_notes" {
  type        = string
  description = "Notes about why the lock is in place"
  default     = "Locked by Terraform to prevent accidental deletion"
}

# vNET
# ============================================================================
# Required Variables
# ============================================================================

variable "resource_group_name" {
  description = "Resource group where the vNet will be created."
  type        = string
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the VNet (e.g., ['10.0.0.0/16'])"

  validation {
    condition     = length(var.address_space) > 0
    error_message = "At least one address space must be specified"
  }
}

variable "dns_servers" {
  type        = list(string)
  description = "List of custom DNS servers (optional, uses Azure default if not specified)"
  default     = []
}

variable "ddos_protection_plan_id" {
  type        = string
  description = "ID of DDoS protection plan to associate (optional)"
  default     = null
}

# ============================================================================
# Subnet Variables
# ============================================================================

variable "subnets" {
  type = list(object({
    name                                          = string
    address_prefixes                              = list(string)
    service_endpoints                             = optional(list(string), [])
    private_endpoint_network_policies             = optional(string, "Enabled")
    private_link_service_network_policies_enabled = optional(bool, true)
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }), null)
  }))
  description = "List of subnet configurations"
  default     = []
}
