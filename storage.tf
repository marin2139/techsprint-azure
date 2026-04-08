# ─── Storage Account po developeru ───────────────────────────────────────────
# Svaki dev dobiva: Blob Container (objektna pohrana) + File Share (datotečna pohrana)
resource "azurerm_storage_account" "dev" {
  for_each = local.developers

  # Ime mora biti unique, lowercase, max 24 znaka
  name                     = "ts${replace(replace(each.key, "-", ""), ".", "")}sa"
  resource_group_name      = azurerm_resource_group.dev[each.key].name
  location                 = azurerm_resource_group.dev[each.key].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # Onemogući public blob pristup - samo Managed Identity
  allow_nested_items_to_be_public = false
  tags                     = merge(local.common_tags, { owner = each.key })
}

# ─── Blob Container (objektna pohrana za Moodle datoteke) ────────────────────
resource "azurerm_storage_container" "moodle_data" {
  for_each = local.developers

  name                  = "moodle-data"
  storage_account_name  = azurerm_storage_account.dev[each.key].name
  container_access_type = "private"
}

# ─── Azure File Share (datotečna pohrana za backupe) ─────────────────────────
resource "azurerm_storage_share" "moodle_backup" {
  for_each = local.developers

  name                 = "moodle-backup"
  storage_account_name = azurerm_storage_account.dev[each.key].name
  quota                = 50 # GB
}

# ─── RBAC: Managed Identity VM-ova → Storage (least-privilege) ───────────────
# VM-ovi dobivaju Storage Blob Data Contributor samo za vlastiti storage account

