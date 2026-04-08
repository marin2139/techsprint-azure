output "jump_host_public_ip" {
  description = "Javna IP adresa Jump Hosta"
  value       = azurerm_public_ip.jump.ip_address
}

output "load_balancer_public_ip" {
  description = "Javna IP adresa Load Balancera"
  value       = azurerm_public_ip.lb.ip_address
}

output "dev_vm_private_ips" {
  description = "Privatne IP adrese developer VM-ova"
  value = {
    for key, vm in azurerm_linux_virtual_machine.dev_vm :
    key => vm.private_ip_address
  }
}

output "storage_account_names" {
  description = "Imena Storage Accounta po developeru"
  value = {
    for key, sa in azurerm_storage_account.dev :
    key => sa.name
  }
}

output "resource_groups" {
  description = "Sve kreirane resource grupe"
  value = merge(
    { shared = azurerm_resource_group.shared.name },
    { for k, rg in azurerm_resource_group.dev : k => rg.name }
  )
}
