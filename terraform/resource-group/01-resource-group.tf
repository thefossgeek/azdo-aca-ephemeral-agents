resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_management_lock" "this" {
  count = var.enable_lock ? 1 : 0

  name       = "${var.resource_group_name}-lock"
  scope      = azurerm_resource_group.this.id
  lock_level = var.lock_level
  notes      = "Managed by Terraform"

  depends_on = [
    azurerm_resource_group.this
  ]
}
