# ─── Lead/Jump VNet ──────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "lead" {
  name                = "vnet-${var.project}-${var.environment}-lead"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  address_space       = [var.lead_vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "jump" {
  name                 = "snet-jump"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.lead.name
  address_prefixes     = [cidrsubnet(var.lead_vnet_cidr, 8, 1)]
}

# ─── Developer VNets ─────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "developer" {
  for_each = local.developers

  name                = "vnet-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}"
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name
  address_space       = [each.value.vnet_cidr]
  tags                = merge(local.tags, { owner = each.key })
}

resource "azurerm_subnet" "app" {
  for_each = local.developers

  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.developer[each.key].name
  virtual_network_name = azurerm_virtual_network.developer[each.key].name
  address_prefixes     = [each.value.app_cidr]
}

# ─── VNet Peering: Lead <-> Dev ──────────────────────────────────────────────
resource "azurerm_virtual_network_peering" "lead_to_dev" {
  for_each = local.developers

  name                      = "peer-lead-to-${each.value.ime}${each.value.prezime}"
  resource_group_name       = azurerm_resource_group.core.name
  virtual_network_name      = azurerm_virtual_network.lead.name
  remote_virtual_network_id = azurerm_virtual_network.developer[each.key].id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

resource "azurerm_virtual_network_peering" "dev_to_lead" {
  for_each = local.developers

  name                      = "peer-${each.value.ime}${each.value.prezime}-to-lead"
  resource_group_name       = azurerm_resource_group.developer[each.key].name
  virtual_network_name      = azurerm_virtual_network.developer[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.lead.id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# ─── NSG: Jump Host ──────────────────────────────────────────────────────────
resource "azurerm_network_security_group" "jump" {
  name                = "nsg-${var.project}-${var.environment}-jump"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-SSH-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "jump" {
  subnet_id                 = azurerm_subnet.jump.id
  network_security_group_id = azurerm_network_security_group.jump.id
}

# ─── NSG: App Subnets ────────────────────────────────────────────────────────
resource "azurerm_network_security_group" "app" {
  for_each = local.developers

  name                = "nsg-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}-app"
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name
  tags                = merge(local.tags, { owner = each.key })

  security_rule {
    name                       = "Allow-SSH-From-Lead-VNet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.lead_vnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefixes    = [var.lead_vnet_cidr, each.value.vnet_cidr]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-LB-Probe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  for_each = local.developers

  subnet_id                 = azurerm_subnet.app[each.key].id
  network_security_group_id = azurerm_network_security_group.app[each.key].id
}

# ─── ASG za Moodle VM-ove ────────────────────────────────────────────────────
resource "azurerm_application_security_group" "app" {
  for_each = local.developers

  name                = "asg-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}-moodle"
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name
  tags                = merge(local.tags, { owner = each.key })
}

# ─── Public IP - SAMO Jump Host ──────────────────────────────────────────────
resource "azurerm_public_ip" "jump" {
  name                = "pip-${var.project}-${var.environment}-jump"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# ─── Load Balancer po developeru (interni) ───────────────────────────────────
resource "azurerm_lb" "developer" {
  for_each = local.developers

  name                = "lb-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}"
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name
  sku                 = "Standard"
  tags                = merge(local.tags, { owner = each.key })

  frontend_ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app[each.key].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.lb_ip
  }
}

resource "azurerm_lb_backend_address_pool" "developer" {
  for_each = local.developers

  name            = "pool-moodle"
  loadbalancer_id = azurerm_lb.developer[each.key].id
}

resource "azurerm_lb_probe" "developer" {
  for_each = local.developers

  name            = "probe-http"
  loadbalancer_id = azurerm_lb.developer[each.key].id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "developer" {
  for_each = local.developers

  name                           = "rule-http"
  loadbalancer_id                = azurerm_lb.developer[each.key].id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "internal"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.developer[each.key].id]
  probe_id                       = azurerm_lb_probe.developer[each.key].id
}

# ─── NAT Gateway za internet izlaz dev VM-ova ────────────────────────────────
resource "azurerm_public_ip" "developer_nat" {
  for_each = local.developers

  name                = "pip-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}-nat"
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.tags, { owner = each.key })
}

resource "azurerm_nat_gateway" "developer" {
  for_each = local.developers

  name                = "nat-${var.project}-${var.environment}-${each.value.ime}${each.value.prezime}"
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name
  sku_name            = "Standard"
  tags                = merge(local.tags, { owner = each.key })
}

resource "azurerm_nat_gateway_public_ip_association" "developer" {
  for_each = local.developers

  nat_gateway_id       = azurerm_nat_gateway.developer[each.key].id
  public_ip_address_id = azurerm_public_ip.developer_nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "app" {
  for_each = local.developers

  subnet_id      = azurerm_subnet.app[each.key].id
  nat_gateway_id = azurerm_nat_gateway.developer[each.key].id
}
