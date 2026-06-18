data "azuredevops_project" "this" {
  name = var.ado_project_name
}

resource "azuredevops_agent_pool" "this" {
  name           = var.agent_pool_name
  auto_provision = false
  auto_update    = true
}

resource "azuredevops_agent_queue" "this" {
  project_id    = data.azuredevops_project.this.id
  agent_pool_id = azuredevops_agent_pool.this.id
}

resource "azurerm_user_assigned_identity" "this" {
  location            = var.location
  name                = var.uami_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_management_lock" "this" {
  count = var.enable_lock ? 1 : 0

  name       = "${var.uami_name}-lock"
  scope      = azurerm_user_assigned_identity.this.id
  lock_level = var.lock_level
  notes      = "Managed by Terraform"

  depends_on = [
    azurerm_user_assigned_identity.this
  ]
}

resource "time_sleep" "uami_propagation" {
  create_duration = "30s"

  depends_on = [azurerm_user_assigned_identity.this]
}

resource "azuredevops_service_principal_entitlement" "uami" {
  account_license_type = "express"
  origin               = "aad"
  origin_id            = azurerm_user_assigned_identity.this.principal_id

  depends_on = [
    time_sleep.uami_propagation
  ]
}

resource "time_sleep" "entitlement_propagation" {
  create_duration = "60s"

  depends_on = [azuredevops_service_principal_entitlement.uami]
}

# Grant the UAMI the Administrator role on the org-level agent pool. The
# lower-privilege Service Account role only permits an already-registered
# agent to create sessions and listen for jobs; it does not grant the Manage
# permission needed to register a new agent. This module's containers are
# ephemeral and call POST /_apis/distributedtask/pools/{poolId}/agents on
# every start, so Administrator is the lowest built-in role that works.
resource "azuredevops_securityrole_assignment" "uami_pool_admin" {
  scope       = "distributedtask.agentpoolrole"
  resource_id = azuredevops_agent_pool.this.id
  # Must be the AzDO Service Principal UUID (entitlement id), not the AAD object id;
  # the provider polls the role assignment until the returned Identity.ID matches identity_id.
  identity_id = azuredevops_service_principal_entitlement.uami.id
  role_name   = "Administrator"

  depends_on = [time_sleep.entitlement_propagation]
}

resource "azurerm_role_assignment" "this" {

  for_each = {
    for idx, ra in var.role_assignments :
    idx => ra
  }

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this.principal_id

  depends_on = [azurerm_user_assigned_identity.this]
}

