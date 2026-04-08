terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}
}

# ─── Lokalne varijable ────────────────────────────────────────────────────────
locals {
  # Konvencija imenovanja: {projekt}-{okolina}-{tip}-{korisnik/redni broj}
  # Primjer: ts-test-vm-dev1, ts-test-vnet-dev1
  prefix = "ts-test"

  common_tags = {
    project     = "techsprint"
    environment = "testing"
  }

  # Parsiranje CSV-a dolazi iz deploy.sh koji generira terraform.tfvars
  # Format CSV: ime;prezime;rola
  developers = { for u in var.users : u.username => u if u.role == "developer" }
  leads      = { for u in var.users : u.username => u if u.role == "devops_lead" }
}

# ─── Resource group za shared resurse (LB, Jump Host, Lead VM) ───────────────
resource "azurerm_resource_group" "shared" {
  name     = "${local.prefix}-rg-shared"
  location = var.location
  tags     = local.common_tags
}

# ─── Resource group po developeru ────────────────────────────────────────────
resource "azurerm_resource_group" "dev" {
  for_each = local.developers

  name     = "${local.prefix}-rg-${each.key}"
  location = var.location
  tags     = merge(local.common_tags, { owner = each.key })
}
