output "jump_public_ip" {
  description = "Javna IP adresa Jump Hosta"
  value       = azurerm_public_ip.jump.ip_address
}

output "developer_load_balancers" {
  description = "Interne LB IP adrese po developeru"
  value = {
    for key, dev in local.developers : key => azurerm_lb.developer[key].frontend_ip_configuration[0].private_ip_address
  }
}

output "app_private_ips" {
  description = "Privatne IP adrese app VM-ova"
  value = {
    for key, nic in azurerm_network_interface.app : key => nic.private_ip_address
  }
}

output "resource_groups" {
  description = "Sve kreirane resource grupe"
  value = concat(
    [azurerm_resource_group.core.name],
    [for rg in azurerm_resource_group.developer : rg.name]
  )
}
