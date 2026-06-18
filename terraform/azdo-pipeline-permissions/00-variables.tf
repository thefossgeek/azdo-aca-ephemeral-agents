variable "project_id" {
  description = "AzDO project ID. Read from the azdo-ephemeral-agent-aca stack output."
  type        = string
}

variable "agent_queue_id" {
  description = "Project-level agent queue ID. Read from the azdo-ephemeral-agent-aca stack output."
  type        = string
}

variable "pipelines" {
  description = <<-EOT
    Map of pipeline name → AzDO pipeline definition ID.
    Add a new entry each time a new pipeline needs access to the agent pool.
    Find the definition ID in the AzDO URL when viewing the pipeline:
      https://dev.azure.com/<org>/<project>/_build?definitionId=<ID>
  EOT
  type        = map(number)
  default     = {}
}

variable "authorize_all_pipelines" {
  description = <<-EOT
    When true, ALL pipelines in the project can use the agent queue without
    needing individual entries in var.pipelines. Convenient but less secure.
    Recommended only for non-production environments.
  EOT
  type        = bool
  default     = false
}
