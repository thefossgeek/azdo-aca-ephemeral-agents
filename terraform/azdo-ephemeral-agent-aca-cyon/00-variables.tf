# ============================================================================
# Common variables (location, environment, product, location_code, tenant_id,
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
  description = "Name of the resource group to create for all resources."
  type        = string
}

variable "enable_rg_lock" {
  description = "Enable a CanNotDelete lock on the resource group."
  type        = bool
  default     = false
}

# ============================================================================
# Virtual Network
# ============================================================================

variable "workload" {
  description = "Workload name used in the VNet resource name."
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network (e.g. [\"10.0.0.0/16\"])."
  type        = list(string)

  validation {
    condition     = length(var.address_space) > 0
    error_message = "At least one address space must be specified."
  }
}

variable "dns_servers" {
  description = "Custom DNS servers. Defaults to Azure-provided DNS when empty."
  type        = list(string)
  default     = []
}

variable "ddos_protection_plan_id" {
  description = "Resource ID of a DDoS protection plan to attach (optional)."
  type        = string
  default     = null
}

variable "subnets" {
  description = "Subnet configurations for the virtual network."
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
  default = []
}

variable "infra_subnet_name" {
  description = "Name of the subnet (from var.subnets) delegated to the Container App Environment infrastructure."
  type        = string
}

variable "enable_vnet_lock" {
  description = "Enable a resource lock on the virtual network."
  type        = bool
  default     = false
}

variable "enable_udr" {
  description = "Route all subnet traffic through the hub firewall via UDR. Disable during testing, enable for prod."
  type        = bool
  default     = false
}

variable "hub_firewall_ip" {
  description = "Private IP of the hub FortiGate firewall. Required when enable_udr = true."
  type        = string
  default     = null
}

variable "udr_subnet_names" {
  description = "Subnet names to associate with the UDR. Leave empty to apply to all subnets. Best practice: specify only the agent subnet(s)."
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
