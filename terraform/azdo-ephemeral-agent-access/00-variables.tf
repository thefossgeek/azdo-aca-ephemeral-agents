variable "location" {
  description = "Azure region where the managed identity will be created."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "ado_project_name" {
  description = "Azure DevOps project name."
  type        = string
}

variable "agent_pool_name" {
  description = "Name of the Azure DevOps agent pool. Prefix: pool-"
  type        = string
}

variable "uami_name" {
  description = "Name of the User Assigned Managed Identity. Prefix: id-"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where the managed identity will be created."
  type        = string
}

variable "enable_lock" {
  description = "Enable CanNotDelete lock on the managed identity."
  type        = bool
  default     = false
}

variable "lock_level" {
  description = "Lock level: CanNotDelete or ReadOnly."
  type        = string
  default     = "CanNotDelete"
}

variable "role_assignments" {
  description = "List of RBAC role assignments to grant to the managed identity."
  type = list(object({
    scope = string
    role  = string
  }))
  default = []
}

#variable "azdo_org_url" {
#  description = "Azure DevOps organization URL (e.g. https://dev.azure.com/myorg)."
#  type        = string
#}
