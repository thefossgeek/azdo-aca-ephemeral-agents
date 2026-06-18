variable "location" {
  description = "Azure region where the resource group will be created."
  type        = string
}

variable "tags" {
  description = "Tags to apply to the resource group."
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "Resource group for managed identity."
  type        = string
}

variable "enable_lock" {
  description = "Enable deletion lock on resource group."
  type        = bool
  default     = false
}

variable "lock_level" {
  description = "Lock level (CanNotDelete or ReadOnly)."
  type        = string
  default     = "CanNotDelete"
}
