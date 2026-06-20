data "azuredevops_project" "this" {
  name = var.project_name
}

data "azuredevops_git_repository" "this" {
  project_id = data.azuredevops_project.this.id
  name       = var.repository_name
}

locals {
  all_vg_names = distinct(flatten([for p in var.pipelines : p.variable_groups]))
}

data "azuredevops_variable_group" "this" {
  for_each   = toset(local.all_vg_names)
  project_id = data.azuredevops_project.this.id
  name       = each.value
}
