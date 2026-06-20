resource "azuredevops_build_definition" "this" {
  for_each = var.pipelines

  project_id = data.azuredevops_project.this.id
  name = each.key
  path = coalesce(each.value.folder, var.folder)

  # All trigger configuration lives in the YAML file — no drift between portal and code.
  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = data.azuredevops_git_repository.this.id
    branch_name = var.default_branch
    yml_path    = each.value.yml_path
  }

  variable_groups = [
    for name in each.value.variable_groups :
    data.azuredevops_variable_group.this[name].id
  ]
}
