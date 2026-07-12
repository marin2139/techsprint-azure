# ─── Storage Account po developeru ───────────────────────────────────────────
resource "azurerm_storage_account" "developer" {
  for_each = local.developers

  name                            = substr(replace("st${var.project}${each.value.ime}${random_string.suffix.result}", "-", ""), 0, 24)
  location                        = azurerm_resource_group.developer[each.key].location
  resource_group_name             = azurerm_resource_group.developer[each.key].name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  tags                            = merge(local.tags, { owner = each.key })
}

# ─── Blob Container (objektna pohrana za Moodle) ─────────────────────────────
resource "azurerm_storage_container" "moodle" {
  for_each = local.developers

  name                  = "moodle-objects"
  storage_account_name  = azurerm_storage_account.developer[each.key].name
  container_access_type = "private"
}

# ─── Azure File Share (datotečna pohrana za backupe) ──────────────────────────
resource "azurerm_storage_share" "backups" {
  for_each = local.developers

  name                 = "moodle-backups"
  storage_account_name = azurerm_storage_account.developer[each.key].name
  quota                = 50
}
