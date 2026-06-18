locals {
  job_name    = "caj-${var.project}-${var.environment}-${var.agent_type}-${var.instance}"
  keda_secret = "keda-pat"
}

resource "azurerm_container_app_job" "this" {
  name                         = local.job_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.cae_id
  workload_profile_name        = "Consumption"
  replica_timeout_in_seconds   = var.replica_timeout_in_seconds
  replica_retry_limit          = 0

  identity {
    type         = "UserAssigned"
    identity_ids = [var.uami_id]
  }

  registry {
    server   = var.acr_server
    identity = var.uami_id
  }

  template {
    container {
      name   = "agent"
      image  = var.agent_image
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "AZP_URL"
        value = var.azdo_org_url
      }
      env {
        name  = "AZP_POOL"
        value = var.azdo_pool_name
      }
      env {
        name  = "AZP_AGENT_NAME_PREFIX"
        value = var.agent_type
      }
      env {
        name  = "AZP_RANDOM_AGENT_SUFFIX"
        value = "true"
      }
      env {
        name  = "USRMI_ID"
        value = var.uami_client_id
      }
      env {
        name  = "USE_MANAGED_IDENTITY"
        value = "true"
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = var.uami_client_id
      }
      env {
        name  = "AZURE_TENANT_ID"
        value = var.tenant_id
      }
    }
  }

  event_trigger_config {
    parallelism              = 1
    replica_completion_count = 1

    scale {
      polling_interval_in_seconds = 15
      max_executions              = var.max_executions
      min_executions              = 0

      rules {
        name             = "azp-scaler"
        custom_rule_type = "azure-pipelines"

        metadata = {
          organizationURL            = var.azdo_org_url
          poolID                     = var.azdo_pool_id
          targetPipelinesQueueLength = "1"
        }

        authentication {
          trigger_parameter = "personalAccessToken"
          secret_name       = local.keda_secret
        }
      }
    }
  }

  secret {
    name  = local.keda_secret
    value = var.azdo_keda_pat
  }
}
