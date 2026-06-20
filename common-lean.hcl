// Minimum Terraform version required for this configuration
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

// Minimal globals — only subscription_id and tenant_id.
// location, environment, location_code, tags are NOT generated here;
// they are declared in each module's own 00-variables.tf.
// Use this common file for stacks whose module already declares those variables.

generate "globals" {
  path              = "globals.tf"
  if_exists         = "overwrite"
  disable_signature = true

  contents = <<EOF
variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}
EOF
}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite"

  contents = <<EOF
provider "azurerm" {
  subscription_id     = var.subscription_id
  tenant_id           = var.tenant_id
  storage_use_azuread = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

terraform {
  backend "azurerm" {}
}
EOF
}
