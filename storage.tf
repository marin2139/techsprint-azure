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

# ─── File Share mount: storage account ključ (jedina opcija za SMB) ──────────
# NAPOMENA: pokušali smo SAS token za mount.cifs (kao za Blob preko MSI), ali
# Azure Files SMB protokol (mount -t cifs) ne podržava SAS token kao lozinku -
# to je dokumentirano Azure ograničenje, ne propust u dizajnu. SMB basic auth
# prihvaća SAMO storage account ključ ili Azure AD Kerberos (zahtijeva domain
# join, prekompleksno za ovaj scenarij). Least-privilege je ovdje osiguran na
# drugoj razini: ključ je vezan za storage account TOG developera (nije
# dijeljen), čita se samo unutar cloud-init-a i sprema na disk s 0600
# dozvolama (vidi cloud-init-app.yaml.tpl). Blob i dalje ide isključivo preko
# Managed Identity (bez ikakve tajne) - vidi source_image_reference blok i
# azurerm_role_assignment.app_blob_data_contributor u iam.tf.
