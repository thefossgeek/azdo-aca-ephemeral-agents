# ============================================================================
# Common variables (location, environment, location_code, tenant_id,
# tags, subscription_id) are declared by the Terragrunt-generated globals.tf
# and must NOT be re-declared here.
# ============================================================================

# ============================================================================
# Naming / Instance
# ============================================================================

variable "instance" {
  description = "Zero-padded instance number to distinguish multiple deployments (e.g. 001)."
  type        = string
  default     = "001"
}

# ============================================================================
# Resource Group
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group to create for all agent resources."
  type        = string
}

variable "enable_rg_lock" {
  description = "Enable a CanNotDelete lock on the resource group."
  type        = bool
  default     = false
}

variable "create_resource_group" {
  description = "Set to false when the resource group already exists and should only be looked up, not created."
  type        = bool
  default     = true
}

# ============================================================================
# Virtual Network — existing (looked up via data source, not created)
# ============================================================================

variable "vnet_name" {
  description = "Name of the existing virtual network to look up."
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Resource group where the existing virtual network lives. Defaults to resource_group_name when null (same RG)."
  type        = string
  default     = null
}

variable "infra_subnet_name" {
  description = "Name of the existing subnet delegated to the Container App Environment infrastructure."
  type        = string
}

# ============================================================================
# UDR — Hub Firewall Routing (optional)
# ============================================================================

variable "enable_udr" {
  description = "Route subnet traffic through the hub firewall via a UDR. When true, hub_firewall_ip must be set."
  type        = bool
  default     = false
}

variable "hub_firewall_ip" {
  description = "Private IP of the hub FortiGate firewall. Required when enable_udr = true."
  type        = string
  default     = null
}

variable "udr_subnet_names" {
  description = "Names of existing subnets to associate with the UDR. Best practice: specify only the agent subnet(s)."
  type        = list(string)
  default     = []
}

# ============================================================================
# Azure DevOps Access (UAMI + Agent Pool)
# ============================================================================

variable "ado_project_name" {
  description = "Name of the Azure DevOps project."
  type        = string
}

variable "agent_pool_name" {
  description = "Name of the Azure DevOps agent pool to create."
  type        = string
}

variable "uami_name" {
  description = "Name of the User Assigned Managed Identity for the ephemeral agents."
  type        = string
}

variable "role_assignments" {
  description = "Azure RBAC role assignments to grant to the managed identity (e.g. AcrPull on the ACR)."
  type = list(object({
    scope = string
    role  = string
  }))
  default = []
}

# ============================================================================
# Container App Environment
# ============================================================================

variable "project" {
  description = "Short project code used in ACA resource naming (e.g. spai)."
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

# ============================================================================
# Container App Job (Ephemeral Agent)
# ============================================================================

variable "agent_type" {
  description = "Agent image type label — used in the job name and as AZP_AGENT_NAME_PREFIX (e.g. devops, alpine)."
  type        = string
}

variable "acr_server" {
  description = "Azure Container Registry login server (e.g. myacr.azurecr.io)."
  type        = string
}

variable "agent_image" {
  description = "Full container image reference for the ephemeral agent."
  type        = string
}

variable "azdo_org_url" {
  description = "Azure DevOps organization URL (e.g. https://dev.azure.com/myorg)."
  type        = string
}

variable "azdo_keda_pat" {
  description = "Azure DevOps PAT for KEDA queue polling. Required scope: Agent Pools (Read)."
  type        = string
  sensitive   = true
}

variable "cpu" {
  description = "vCPU allocated per agent container."
  type        = string
  default     = "1.0"
}

variable "memory" {
  description = "Memory allocated per agent container."
  type        = string
  default     = "2Gi"
}

variable "max_executions" {
  description = "Maximum number of agent containers running in parallel."
  type        = number
  default     = 10
}

variable "replica_timeout_in_seconds" {
  description = "Hard stop time limit per pipeline job in seconds."
  type        = number
  default     = 1800
}

variable "keda_parent" {
  description = "Name of the manually-created offline placeholder agent in Azure DevOps for KEDA capability filtering."
  type        = string
  default     = ""
}
