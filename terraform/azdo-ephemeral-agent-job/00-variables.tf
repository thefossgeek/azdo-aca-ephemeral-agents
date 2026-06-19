variable "location" {
  description = "Azure region where the Container App Job will be created."
  type        = string
}

variable "environment" {
  description = "Environment name used in resource naming (e.g. dev, staging, prod)."
  type        = string
}

variable "tenant_id" {
  description = "Azure Active Directory tenant ID, injected as AZURE_TENANT_ID into the agent container."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where the Container App Job will be created."
  type        = string
}

variable "project" {
  description = "Short project code for resource names (e.g. spai)."
  type        = string
}

variable "instance" {
  description = "Zero-padded instance number to distinguish multiple jobs of the same type (e.g. 001)."
  type        = string
  default     = "001"
}

variable "agent_type" {
  description = "Agent image type, used in the job name (e.g. devops, alpine)."
  type        = string
}

variable "cae_id" {
  description = "Resource ID of the Container App Environment this job runs in."
  type        = string
}

variable "acr_server" {
  description = "Azure Container Registry login server (e.g. myacr.azurecr.io)."
  type        = string
}

variable "uami_id" {
  description = "Full resource ID of the UAMI for image pull and AzDO authentication."
  type        = string
}

variable "uami_client_id" {
  description = "Client ID of the UAMI."
  type        = string
}

variable "azdo_org_url" {
  description = "Azure DevOps organization URL."
  type        = string
}

variable "azdo_pool_name" {
  description = "Azure DevOps agent pool the job agents register into."
  type        = string
}

variable "azdo_pool_id" {
  description = "Numeric ID of the Azure DevOps agent pool (required by KEDA scaler)."
  type        = string
}

variable "azdo_keda_pat" {
  description = "Azure DevOps PAT for KEDA queue polling. Required scope: Agent Pools (Read)."
  type        = string
  sensitive   = true
}

variable "agent_image" {
  description = "Full container image path for the ephemeral agent."
  type        = string
}

variable "cpu" {
  description = "vCPU allocated to each agent container."
  type        = string
  default     = "1.0"
}

variable "memory" {
  description = "Memory allocated to each agent container."
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
  description = "Name of the manually-created offline placeholder agent in Azure DevOps. KEDA checks its capabilities to filter the queue — only jobs matching this agent's capabilities trigger scaling. Leave empty to disable filtering."
  type        = string
  default     = ""
}
