# ─── NIC za Jump Host ────────────────────────────────────────────────────────
resource "azurerm_network_interface" "jump" {
  name                = "${local.prefix}-nic-jump"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump.id
  }
}

resource "azurerm_linux_virtual_machine" "jump" {
  name                = "${local.prefix}-vm-jump"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  size                = var.vm_size_jump
  admin_username      = var.admin_username
  tags                = local.common_tags
  network_interface_ids = [azurerm_network_interface.jump.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "${local.prefix}-osdisk-jump"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }
}

# ─── NIC za DevOps Lead VM ────────────────────────────────────────────────────
resource "azurerm_network_interface" "lead" {
  for_each            = local.leads
  name                = "${local.prefix}-nic-lead-${each.key}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "lead" {
  for_each            = local.leads
  name                = "${local.prefix}-vm-lead-${each.key}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  size                = var.vm_size_app
  admin_username      = var.admin_username
  tags                = merge(local.common_tags, { owner = each.key, role = "devops_lead" })
  network_interface_ids = [azurerm_network_interface.lead[each.key].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity { type = "SystemAssigned" }

  os_disk {
    name                 = "${local.prefix}-osdisk-lead-${each.key}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }
}

# ─── Dev VM-ovi (1 po developeru zbog vCPU kvote na Students subscriptionu) ──
resource "azurerm_network_interface" "dev_vm" {
  for_each            = local.developers
  name                = "${local.prefix}-nic-${each.key}"
  resource_group_name = azurerm_resource_group.dev[each.key].name
  location            = azurerm_resource_group.dev[each.key].location
  tags                = merge(local.common_tags, { owner = each.key })

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.dev_app[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "dev_vm" {
  for_each            = local.developers
  name                = "${local.prefix}-vm-${each.key}"
  resource_group_name = azurerm_resource_group.dev[each.key].name
  location            = azurerm_resource_group.dev[each.key].location
  size                = var.vm_size_app
  admin_username      = var.admin_username
  tags                = merge(local.common_tags, { owner = each.key, role = "developer" })
  network_interface_ids = [azurerm_network_interface.dev_vm[each.key].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity { type = "SystemAssigned" }

  os_disk {
    name                 = "${local.prefix}-osdisk-${each.key}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }
}

# ─── Data disk po VM-u ────────────────────────────────────────────────────────
resource "azurerm_managed_disk" "data" {
  for_each             = local.developers
  name                 = "${local.prefix}-datadisk-${each.key}"
  resource_group_name  = azurerm_resource_group.dev[each.key].name
  location             = azurerm_resource_group.dev[each.key].location
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
  tags                 = merge(local.common_tags, { owner = each.key })
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  for_each           = local.developers
  managed_disk_id    = azurerm_managed_disk.data[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.dev_vm[each.key].id
  lun                = 0
  caching            = "ReadWrite"
}
