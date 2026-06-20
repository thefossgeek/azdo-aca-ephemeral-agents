variable "project_name" {
  description = "Azure DevOps project name."
  type        = string
}

variable "repository_name" {
  description = "Git repository name within the project."
  type        = string
}

variable "default_branch" {
  description = "Default branch for all pipelines."
  type        = string
  default     = "refs/heads/main"
}

variable "folder" {
  description = "Default Azure DevOps UI folder for pipelines (e.g. \\\\Build). Override per-pipeline with pipelines[*].folder."
  type        = string
  default     = "\\"
}

variable "pipelines" {
  description = <<-EOT
    Map of pipeline display name → configuration.
    Each entry registers one pipeline in Azure DevOps.

    yml_path        : path to the YAML file in the repository
    folder          : override the default folder for this pipeline
    variable_groups : names of variable groups to link (looked up by name)
  EOT
  type = map(object({
    yml_path        = string
    folder          = optional(string, null)
    variable_groups = optional(list(string), [])
  }))
}
