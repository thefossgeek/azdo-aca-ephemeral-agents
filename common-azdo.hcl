// For Azure DevOps-only stacks that don't manage Azure resources.
// Uses azurerm backend for state but does not configure the azurerm resource provider.
// Credentials are read from environment:
//   AZDO_ORG_SERVICE_URL        — https://dev.azure.com/<org>
//   AZDO_PERSONAL_ACCESS_TOKEN  — pipeline registration PAT

terraform_version_constraint = ">= 1.15.6"

terraform {
  extra_arguments "common_envs" {
    commands = [
      "apply",
      "import",
      "init",
      "plan",
      "refresh",
      "destroy"
    ]

    env_vars = {
      KUBE_LOAD_CONFIG_FILE = false
    }
  }
}

generate "versions" {
  path              = "versions.tf"
  if_exists         = "overwrite"
  contents          = file(find_in_parent_folders("versions.tf"))
  disable_signature = true
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

remote_state {
  backend = "azurerm"

  config = {
    resource_group_name  = local.env.locals.tfbackend_resource_group
    storage_account_name = local.env.locals.tfbackend_state_storage_account
    container_name       = local.env.locals.tfbackend_container_name
    key                  = "${path_relative_to_include()}"
    use_azuread_auth     = true
    use_oidc             = true
    subscription_id      = local.env.locals.tfbackend_subscription_id
  }
}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite"

  contents = <<EOF
provider "azuredevops" {
  # org_service_url and personal_access_token read from env:
  # AZDO_ORG_SERVICE_URL, AZDO_PERSONAL_ACCESS_TOKEN
}

terraform {
  backend "azurerm" {}
}
EOF
}
