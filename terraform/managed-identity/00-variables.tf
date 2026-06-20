# Common variables (location, tags, subscription_id, tenant_id, environment,
# location_code) are declared by the Terragrunt-generated globals.tf and must
# NOT be re-declared here.

variable "name" {
  description = "Name of the User Assigned Managed Identity."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group where the managed identity will be created."
  type        = string
}

variable "role_assignments" {
  description = "List of Azure RBAC role assignments to grant to this managed identity."
  type = list(object({
    scope = string
    role  = string
  }))
  default = []
}
