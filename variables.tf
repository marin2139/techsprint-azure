variable "project" {
  type    = string
  default = "techsprint"
}

variable "environment" {
  type    = string
  default = "testing"
}

variable "location" {
  type    = string
  default = "francecentral"
}

variable "users_csv_path" {
  type        = string
  description = "Putanja do CSV datoteke (ime;prezime;rola)"
  default     = "users.csv"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH javni ključ. Ako prazan, Terraform generira privremeni."
  default     = ""
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "app_vm_size" {
  # NAPOMENA: B1s (1 vCPU) je izbor zbog Total Regional vCPUs kvote testne
  # Azure for Students pretplate (limit = 6 vCPU regionalno). Uz Lead VM i
  # HA (2 Moodle VM-a po developeru) treba 6 VM-ova ukupno, pa svih 6 mora
  # biti na 1 vCPU da stane u kvotu. U produkciji: Standard_B2s / D2s_v3.
  type    = string
  default = "Standard_B1s"
}

variable "jump_vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "lead_vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "os_disk_size_gb" {
  type    = number
  default = 64
}

variable "data_disk_size_gb" {
  type    = number
  default = 32
}

variable "image_publisher" {
  type    = string
  default = "Canonical"
}

variable "image_offer" {
  type    = string
  default = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  type    = string
  default = "22_04-lts-gen2"
}

variable "image_version" {
  type    = string
  default = "latest"
}

variable "lead_vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "developer_vnet_base_octet" {
  type    = number
  default = 10
}
