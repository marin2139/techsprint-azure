variable "location" {
  description = "Azure regija"
  type        = string
  default     = "westeurope"
}

variable "admin_username" {
  description = "Admin korisnik za sve VM-ove"
  type        = string
  default     = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH javni ključ za pristup VM-ovima"
  type        = string
}

variable "users" {
  description = "Lista korisnika iz CSV-a"
  type = list(object({
    first_name = string
    last_name  = string
    username   = string
    role       = string
  }))
}

variable "vm_size_app" {
  description = "Veličina aplikacijskih VM-ova (2 vCPU, 4GB RAM)"
  type        = string
  default     = "Standard_B1s"
}

variable "vm_size_jump" {
  description = "Veličina jump host VM-a"
  type        = string
  default     = "Standard_B1s"
}

variable "os_image" {
  description = "OS image - Rocky Linux ekvivalent (RHEL compatible)"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "8_5-gen2"
    version   = "latest"
  }
}
