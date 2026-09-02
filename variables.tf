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
  # NAPOMENA: Standard_A1_v2 (1 vCPU) je izbor zbog vCPU kvote testne Azure
  # for Students pretplate. "standardBSFamily" (B1s/B2s/...) ima zaseban
  # strop od 4 vCPU koji Jump+Lead VM (2x B1s) + prva dva Moodle VM-a već
  # potpuno potroše, pa preostala dva Moodle VM-a (HA za 2. developera) NE
  # STANU u istu obitelj čak ni na B1s. Standard_A1_v2 je u zasebnoj "Standard
  # A0-A7 Family" kvoti (odvojen limit, prazan), pa svi Moodle VM-ovi idu
  # tamo umjesto u B-obitelj - time cijela topologija (Jump+Lead+4xMoodle =
  # 6 VM-ova, sve po 1 vCPU) stane u ukupni regionalni limit od 6 vCPU.
  # U produkciji s normalnom kvotom: Standard_B2s / Standard_D2s_v3.
  type    = string
  default = "Standard_A1_v2"
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
