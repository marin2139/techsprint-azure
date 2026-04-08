# ─── Management VNet (Jump Host + Lead VM) ───────────────────────────────────
resource "azurerm_virtual_network" "mgmt" {
  name                = "${local.prefix}-vnet-mgmt"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "mgmt" {
  name                 = "snet-mgmt"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.mgmt.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ─── NSG za management subnet ────────────────────────────────────────────────
resource "azurerm_network_security_group" "mgmt" {
  name                = "${local.prefix}-nsg-mgmt"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = local.common_tags

  # SSH pristup jump hostu samo s interneta
  security_rule {
    name                       = "allow-ssh-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTP/HTTPS za load balancer
  security_rule {
    name                       = "allow-http-inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "mgmt" {
  subnet_id                 = azurerm_subnet.mgmt.id
  network_security_group_id = azurerm_network_security_group.mgmt.id
}

# ─── VNet po developeru ───────────────────────────────────────────────────────
resource "azurerm_virtual_network" "dev" {
  for_each = local.developers

  name                = "${local.prefix}-vnet-${each.key}"
  resource_group_name = azurerm_resource_group.dev[each.key].name
  location            = azurerm_resource_group.dev[each.key].location
  # Svaki dev dobiva zasebni /16 blok - nema peeringa između dev VNet-ova
  address_space = ["10.${index(keys(local.developers), each.key) + 1}.0.0/16"]
  tags          = merge(local.common_tags, { owner = each.key })
}

resource "azurerm_subnet" "dev_app" {
  for_each = local.developers

  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.dev[each.key].name
  virtual_network_name = azurerm_virtual_network.dev[each.key].name
  address_prefixes     = ["10.${index(keys(local.developers), each.key) + 1}.1.0/24"]
}

# ─── NSG za dev subnete ───────────────────────────────────────────────────────
resource "azurerm_network_security_group" "dev" {
  for_each = local.developers

  name                = "${local.prefix}-nsg-${each.key}"
  resource_group_name = azurerm_resource_group.dev[each.key].name
  location            = azurerm_resource_group.dev[each.key].location
  tags                = merge(local.common_tags, { owner = each.key })

  # SSH pristup SAMO iz management subneta (jump host + lead VM)
  security_rule {
    name                       = "allow-ssh-from-mgmt"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # HTTP/HTTPS za Moodle (dolazi s LB-a)
  security_rule {
    name                       = "allow-http-from-lb"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Blokiranje svog ostalog inbound prometa
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dev" {
  for_each = local.developers

  subnet_id                 = azurerm_subnet.dev_app[each.key].id
  network_security_group_id = azurerm_network_security_group.dev[each.key].id
}

# ─── VNet peering: Management <-> Dev (za SSH i LB) ──────────────────────────
resource "azurerm_virtual_network_peering" "mgmt_to_dev" {
  for_each = local.developers

  name                      = "peer-mgmt-to-${each.key}"
  resource_group_name       = azurerm_resource_group.shared.name
  virtual_network_name      = azurerm_virtual_network.mgmt.name
  remote_virtual_network_id = azurerm_virtual_network.dev[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "dev_to_mgmt" {
  for_each = local.developers

  name                      = "peer-${each.key}-to-mgmt"
  resource_group_name       = azurerm_resource_group.dev[each.key].name
  virtual_network_name      = azurerm_virtual_network.dev[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.mgmt.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
}

# ─── Public IP - SAMO za Jump Host ───────────────────────────────────────────
resource "azurerm_public_ip" "jump" {
  name                = "${local.prefix}-pip-jump"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# ─── Public IP za Load Balancer ───────────────────────────────────────────────
resource "azurerm_public_ip" "lb" {
  name                = "${local.prefix}-pip-lb"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# ─── Load Balancer ────────────────────────────────────────────────────────────
resource "azurerm_lb" "main" {
  name                = "${local.prefix}-lb"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Standard"
  tags                = local.common_tags

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "moodle" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "backend-moodle"
}

resource "azurerm_lb_probe" "http" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "probe-http"
  protocol        = "Http"
  port            = 80
  request_path    = "/login/index.php"
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "rule-http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.moodle.id]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_lb_rule" "https" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "rule-https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.moodle.id]
  probe_id                       = azurerm_lb_probe.http.id
}
