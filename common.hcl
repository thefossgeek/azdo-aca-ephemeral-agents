// Minimum Terraform version required for this configuration
terraform_version_constraint = ">= 1.15.6"

terraform {

  ## ---------------------------------------------------------------------------
  ## Extra arguments for all Terraform commands
  ## ---------------------------------------------------------------------------
  ## The "extra_arguments" block allows Terragrunt to inject additional
  ## environment variables or CLI args into Terraform at runtime.
  ## This avoids manually exporting variables in the shell for every run.
  ## ---------------------------------------------------------------------------
  extra_arguments "common_envs" {

    ## Apply these extra arguments to the following Terraform commands
    commands = [
      "apply",
      "import",
      "init",
      "plan",
      "refresh",
      "destroy"
    ]

    ## Environment variables passed automatically to Terraform
    env_vars = {

      ## Prevent Terraform from loading your local kubeconfig file.
      ## This ensures Terraform does not accidentally use the local Kubernetes context.
      KUBE_LOAD_CONFIG_FILE = false
    }
  }
}

generate "versions" {
  # ---------------------------------------------------------------------------
  # Path of the file that Terragrunt will generate inside each Terraform module.
  # This ensures every module receives the same versions.tf file.
  # ---------------------------------------------------------------------------
  path = "versions.tf"

  # ---------------------------------------------------------------------------
  # Overwrite the file if it already exists.
  # This guarantees that all modules always stay in sync with the parent
  # versions.tf without manual updates.
  # ---------------------------------------------------------------------------
  if_exists = "overwrite"

  # ---------------------------------------------------------------------------
  # Load the versions.tf file from the nearest parent folder.
  # This centralizes provider + Terraform version constraints in one place
  # and reuses them across all child modules.
  # ---------------------------------------------------------------------------
  contents = file(find_in_parent_folders("versions.tf"))

  # ---------------------------------------------------------------------------
  # Disable Terragrunt signature comments at the top of the generated file.
  # Keeps versions.tf clean so Terraform formatting tools don't complain.
  # ---------------------------------------------------------------------------
  disable_signature = true
}


locals {
  # ---------------------------------------------------------------------------
  # Load variables from the nearest root.hcl found in parent folders.
  # This allows global settings (subscription, region, backend config, etc.)
  # to be inherited by all child modules without duplicating values.
  # ---------------------------------------------------------------------------
  env = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

remote_state {
  # ---------------------------------------------------------------------------
  # Use the AzureRM backend for Terraform state management.
  # Terragrunt will automatically inject this backend configuration
  # into the generated terraform {} block in the module.
  # ---------------------------------------------------------------------------
  backend = "azurerm"

  config = {

    # Resource group that stores the remote state storage account.
    resource_group_name = local.env.locals.tfbackend_resource_group

    # Storage account for Terraform state files.
    storage_account_name = local.env.locals.tfbackend_state_storage_account

    # Blob container name inside the storage account.
    # All Terraform state files for this repository will go into this container.
    container_name = local.env.locals.tfbackend_container_name

    # The state file key (path) is derived from the folder structure.
    # This ensures each module has a unique state file automatically.
    key = "${path_relative_to_include()}"

    # Enable Azure AD authentication instead of storage access keys.
    use_azuread_auth = true

    # Enable OpenID Connect authentication (GitHub Actions, Azure DevOps, etc.)
    # for secure, keyless Terraform runs.
    use_oidc = true

    # Subscription ID where the storage account exists.
    subscription_id = local.env.locals.tfbackend_subscription_id
  }
}

// This block generates the globals.tf file, which defines shared Terraform variables
// used across the configuration. These include core Azure identifiers (subscription
// and tenant), deployment location, environment designation, and common resource tags.

generate "globals" {
  path      = "globals.tf"
  if_exists = "overwrite"

  contents = <<EOF
variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

variable "location_code" {
  type = string
}

variable "tags" {
  type = map(string)
}

EOF
}

// This block generates the providers.tf file, which configures the AzureRM provider
// using the supplied subscription and tenant information, and initializes the
// Terraform backend configuration for Azure Storage.

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
