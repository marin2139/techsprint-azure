data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# ─── Custom rola za developere ────────────────────────────────────────────────
resource "azurerm_role_definition" "developer" {
  name        = "${local.prefix}-role-developer"
  scope       = data.azurerm_subscription.current.id
  description = "TechSprint developer - moze pokrenuti/ugasiti vlastite VM-ove"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Storage/storageAccounts/read",
    ]
    not_actions = []
  }

  assignable_scopes = [data.azurerm_subscription.current.id]
}

# ─── Custom rola za DevOps Lead ───────────────────────────────────────────────
resource "azurerm_role_definition" "devops_lead" {
  name        = "${local.prefix}-role-devops-lead"
  scope       = data.azurerm_subscription.current.id
  description = "TechSprint DevOps Lead - puna kontrola nad svim resursima"

  permissions {
    actions = [
      "Microsoft.Compute/*/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/powerOff/action",
      "Microsoft.Network/*/read",
      "Microsoft.Storage/*/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
    ]
    not_actions = []
  }

  assignable_scopes = [data.azurerm_subscription.current.id]
}

# ─── Storage RBAC za Managed Identity VM-ova ─────────────────────────────────
resource "azurerm_role_assignment" "vm_blob_access" {
  for_each             = local.developers
  scope                = azurerm_storage_account.dev[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.dev_vm[each.key].identity[0].principal_id
}

resource "azurerm_role_assignment" "vm_file_access" {
  for_each             = local.developers
  scope                = azurerm_storage_account.dev[each.key].id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_linux_virtual_machine.dev_vm[each.key].identity[0].principal_id
}
