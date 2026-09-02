# ─── Jump Host NIC + VM ──────────────────────────────────────────────────────
resource "azurerm_network_interface" "jump" {
  name                = "nic-${var.project}-${var.environment}-jump"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.jump.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump.id
  }
}

resource "azurerm_linux_virtual_machine" "jump" {
  name                  = "vm-${var.project}-${var.environment}-jump"
  location              = azurerm_resource_group.core.location
  resource_group_name   = azurerm_resource_group.core.name
  size                  = var.jump_vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.jump.id]
  tags                  = local.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.ssh_public_key
  }

  os_disk {
    name                 = "disk-${var.project}-${var.environment}-jump-os"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }
}

# ─── Lead VM NIC + VM (bez javnog IP-a, pristup preko Jump Hosta) ───────────
resource "azurerm_network_interface" "lead" {
  for_each = local.leads

  name                = "nic-vm-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}-lead"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = merge(local.tags, { owner = each.key })

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.lead.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "lead" {
  for_each = local.leads

  name                  = "vm-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}-lead"
  location              = azurerm_resource_group.core.location
  resource_group_name   = azurerm_resource_group.core.name
  size                  = var.lead_vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.lead[each.key].id]
  tags                  = merge(local.tags, { owner = each.key, role = "devops_lead" })

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.ssh_public_key
  }

  os_disk {
    name                 = "disk-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}-lead-os"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }
}

# ─── App VM NIC-ovi ──────────────────────────────────────────────────────────
resource "azurerm_network_interface" "app" {
  for_each = local.app_instances

  name                = "nic-${each.value.name}"
  location            = azurerm_resource_group.developer[each.value.dev_key].location
  resource_group_name = azurerm_resource_group.developer[each.value.dev_key].name
  tags                = merge(local.tags, { owner = each.value.dev_key })

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.app[each.value.dev_key].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_application_security_group_association" "app" {
  for_each = local.app_instances

  network_interface_id          = azurerm_network_interface.app[each.key].id
  application_security_group_id = azurerm_application_security_group.app[each.value.dev_key].id
}

resource "azurerm_network_interface_backend_address_pool_association" "app" {
  for_each = local.app_instances

  network_interface_id    = azurerm_network_interface.app[each.key].id
  ip_configuration_name   = "ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.developer[each.value.dev_key].id
}

# ─── App VM-ovi (2 po developeru za HA) ──────────────────────────────────────
resource "azurerm_linux_virtual_machine" "app" {
  for_each = local.app_instances

  name                  = each.value.name
  location              = azurerm_resource_group.developer[each.value.dev_key].location
  resource_group_name   = azurerm_resource_group.developer[each.value.dev_key].name
  size                  = var.app_vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.app[each.key].id]
  tags = merge(local.tags, {
    owner = each.value.dev_key
    role  = "moodle"
  })

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.ssh_public_key
  }

  os_disk {
    name                 = "disk-${each.value.name}-os"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.app_image_sku
    version   = var.image_version
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-app.yaml.tpl", {
    admin_username        = var.admin_username
    instance_name         = each.value.name
    storage_account_name  = azurerm_storage_account.developer[each.value.dev_key].name
    file_share_name       = azurerm_storage_share.backups[each.value.dev_key].name
    file_share_sas_token  = data.azurerm_storage_account_sas.backups[each.value.dev_key].sas
    blob_container_name   = azurerm_storage_container.moodle[each.value.dev_key].name
    azure_storage_dns_suffix = "core.windows.net"
  }))

  depends_on = [
    azurerm_storage_share.backups,
    azurerm_storage_container.moodle
  ]
}

# ─── Data Disk po VM-u ───────────────────────────────────────────────────────
resource "azurerm_managed_disk" "app_data" {
  for_each = local.app_instances

  name                 = "disk-${each.value.name}-data"
  location             = azurerm_resource_group.developer[each.value.dev_key].location
  resource_group_name  = azurerm_resource_group.developer[each.value.dev_key].name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = merge(local.tags, { owner = each.value.dev_key })
}

resource "azurerm_virtual_machine_data_disk_attachment" "app_data" {
  for_each = local.app_instances

  managed_disk_id    = azurerm_managed_disk.app_data[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.app[each.key].id
  lun                = 0
  caching            = "ReadWrite"
}
