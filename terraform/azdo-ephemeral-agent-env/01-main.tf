locals {
  name_prefix = "${var.project}-${var.environment}-${var.location_code}-${var.instance}"
  law_id      = var.create_law ? azurerm_log_analytics_workspace.this[0].id : var.existing_law_id
}

resource "azurerm_log_analytics_workspace" "this" {
  count = var.create_law ? 1 : 0

  name                = "law-${local.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                               = "cae-${local.name_prefix}"
  location                           = var.location
  resource_group_name                = var.resource_group_name
  infrastructure_resource_group_name = "rg-cae-${local.name_prefix}"
  infrastructure_subnet_id           = var.infra_subnet_id
  log_analytics_workspace_id         = local.law_id
  public_network_access          = "Disabled"
  internal_load_balancer_enabled = true
  tags                           = var.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  depends_on = [azurerm_log_analytics_workspace.this]
}
