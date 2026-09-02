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

# ─── RBAC: Developeri → custom rola, ograničeno na VLASTITU resource grupu ───
# Least-privilege: developer smije Start/Restart/Deallocate SAMO svoje VM-ove
# (scope je resource grupa tog developera, ne cijela pretplata).
resource "azurerm_role_assignment" "developer_power" {
  for_each = { for k, v in local.developers : k => v if v.principal_object_id != "" }

  scope              = azurerm_resource_group.developer[each.key].id
  role_definition_id = azurerm_role_definition.vm_power_operator.role_definition_resource_id
  principal_id       = each.value.principal_object_id
}

# ─── RBAC: DevOps Lead → custom rola preko SVIH developerskih resource grupa ─
# Voditelj smije Start/Restart/Deallocate bilo koji VM u projektu, ali i dalje
# bez punih Owner/Contributor ovlasti (nema npr. brisanja resursa, mreže, IAM-a).
#
# NAPOMENA: filtrirano je da preskoči par gdje lead i developer dijele ISTI
# Azure AD principal (npr. u testnom scenariju gdje je jedna stvarna osoba
# dodijeljena svim CSV ulogama) - Azure inače vraća 409 RoleAssignmentExists
# jer bi (scope, rola, principal) bio identičan onome što developer_power već
# kreira za taj isti resource group. U produkciji, s različitim AAD računima
# po developeru/voditelju, ovaj filter ništa ne mijenja (uvjet nikad ne pogađa).
resource "azurerm_role_assignment" "lead_power" {
  for_each = {
    for pair in setproduct(
      [for k, v in local.leads : k if v.principal_object_id != ""],
      keys(local.developers)
    ) : "${pair[0]}-${pair[1]}" => {
      lead_key = pair[0]
      dev_key  = pair[1]
    }
    if local.leads[pair[0]].principal_object_id != local.developers[pair[1]].principal_object_id
  }

  scope              = azurerm_resource_group.developer[each.value.dev_key].id
  role_definition_id = azurerm_role_definition.vm_power_operator.role_definition_resource_id
  principal_id       = local.leads[each.value.lead_key].principal_object_id
}

# Lead dodatno vidi i core RG (Jump Host, vlastiti Lead VM)
resource "azurerm_role_assignment" "lead_power_core" {
  for_each = { for k, v in local.leads : k => v if v.principal_object_id != "" }

  scope              = azurerm_resource_group.core.id
  role_definition_id = azurerm_role_definition.vm_power_operator.role_definition_resource_id
  principal_id       = each.value.principal_object_id
}
