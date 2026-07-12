# ─── Custom rola: VM Power Operator (Start/Deallocate/Restart) ───────────────
resource "azurerm_role_definition" "vm_power_operator" {
  name        = "${var.project}-${var.environment}-vm-power-operator-${random_string.suffix.result}"
  scope       = data.azurerm_subscription.current.id
  description = "TechSprint: Start/Stop/Restart VM-ova (least-privilege)"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

# ─── Storage RBAC: VM Managed Identity → Storage (least-privilege) ───────────
resource "azurerm_role_assignment" "app_blob_data_contributor" {
  for_each = local.app_instances

  scope                = azurerm_storage_account.developer[each.value.dev_key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.app[each.key].identity[0].principal_id
}

# NOTE: Role assignments za developere i lead korisnike trebaju principal_object_id
# iz Azure AD. Ako imaš AAD korisnike, dodaj ih u CSV kao 4. stupac i otkomentiraj:
#
# resource "azurerm_role_assignment" "developer_power" {
#   for_each = { for k, v in local.developers : k => v if v.principal_object_id != "" }
#   scope              = azurerm_resource_group.developer[each.key].id
#   role_definition_id = azurerm_role_definition.vm_power_operator.role_definition_resource_id
#   principal_id       = each.value.principal_object_id
# }
