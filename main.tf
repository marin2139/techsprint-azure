data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

# ─── CSV parsing (ime;prezime;rola) ──────────────────────────────────────────
locals {
  tags = {
    project     = var.project
    environment = var.environment
  }

  ssh_public_key = trimspace(var.ssh_public_key)

  csv_lines = [
    for line in split("\n", replace(file(var.users_csv_path), "\r\n", "\n")) :
    trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#") && !startswith(trimspace(line), "ime")
  ]

  users = [
    for line in local.csv_lines : {
      ime     = lower(trimspace(split(";", line)[0]))
      prezime = lower(trimspace(split(";", line)[1]))
      rola    = lower(trimspace(split(";", line)[2]))
      key     = "${lower(trimspace(split(";", line)[0]))}-${lower(trimspace(split(";", line)[1]))}"
    }
  ]

  developers = {
    for idx, user in [for u in local.users : u if u.rola == "developer"] :
    user.key => merge(user, {
      index     = idx
      vnet_cidr = "10.${var.developer_vnet_base_octet + idx}.0.0/16"
      app_cidr  = "10.${var.developer_vnet_base_octet + idx}.1.0/24"
      lb_ip     = "10.${var.developer_vnet_base_octet + idx}.1.10"
    })
  }

  leads = {
    for user in local.users : user.key => user
    if user.rola == "devops_lead"
  }

  # 1 Moodle VM po developeru (Azure for Students vCPU kvota = 4)
  app_instances = merge([
    for dev_key, dev in local.developers : {
      for n in [1] : "${dev_key}-app${n}" => {
        dev_key         = dev_key
        instance_number = n
        name            = "vm-${var.project}-${dev.ime}${dev.prezime}-app${n}"
      }
    }
  ]...)
}

# ─── Resource Groups ─────────────────────────────────────────────────────────
resource "azurerm_resource_group" "core" {
  name     = "rg-${var.project}-${var.environment}-core"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "developer" {
  for_each = local.developers

  name     = "rg-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}"
  location = var.location
  tags     = merge(local.tags, { owner = each.key })
}
