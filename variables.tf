# This file contains variables definition for the module
# https://www.terraform.io/docs/configuration/variables.html

variable "name_prefix" {
  type        = string
  default     = "secure-transit"
  description = "Prefix for Azure resource names."
}

variable "resource_group_name" {
  type        = string
  default     = "rsg-fortigate-testing"
  description = "Full name for Azure resource group."
}

variable "location" {
  type        = string
  default     = "North Europe"
  description = "Azure region for resources."
}

variable "vnet_prefix" {
  type        = string
  default     = "10.255.0.0/22"
  description = "Prefix for transit VNET. Will be broken into 4 equal subnets."
}

variable "nva_bgp_asn" {
  type        = number
  default     = 65514
  description = "BGP ASN for NVA."
}

variable "nva_type" {
  type        = string
  description = "Type of NVA. Valid options: `fortigate`"
  validation {
    condition     = var.nva_type == "fortigate"
    error_message = "NVA type not supported."
  }
}

variable "username" {
  type        = string
  default     = "fortinet"
  description = "Initial username for admin access."
}

variable "password" {
  type        = string
  default     = "Solarwinds123!"
  description = "Initial password for admin access."
}

variable "trusted_hosts" {
  type = set(object({
    prefix   = string
    name     = string
    priority = number
  }))
  description = "Set of CIDRs to add to NSG for management access to NVA."
  default     = []
}

variable "api_key" {
  type        = string
  description = "API key to cloudinit NVA with."
  default     = null
}

variable "fortigate_sku" {
  type = object({
    byol = string
    payg = string
  })
  default = {
    byol = "fortinet_fg-vm"
    payg = "fortinet_fg-vm_payg_20190624"
  }
  description = "If SKU changes can overwrite here otherwise can leave as default."
}

variable "fortios_version" {
  description = "Target FortiOS version image."
  type        = string
  default     = "latest"
}

variable "fortigate_licenses" {
  description = "Licenses for BYOL Fortigates. If not set will use PAYG."
  type        = list(string)
  default     = null
}

variable "vm_size" {
  description = "Azure VM SKU"
  type        = string
  default     = "Standard_D2ds_v5"
}

variable "create_sslvpn" {
  type        = bool
  default     = true
  description = "Create an ELB and required resources to bootstrap an SSLVPN service."
}

variable "availability_zone_support" {
  type        = bool
  default     = false
  description = "Availability zone support. Ensure region supports this feature."
}

variable "assign_global_reader" {
  type        = bool
  default     = false
  description = "Assign NVA system identity Global Reader in the subscription NVA is created in. Useful for NVAs that can access Azure metadata to create dynamic objects etc. Requires the Service Principal permissions to modify Roles."
}

variable "use_ilb" {
  type        = bool
  default     = false
  description = "Create an internal load balancer. Intention is to allow the NVA to advertise BGP routes towards the Route Server with the ILB frontend address as the next-hop. ILB should deal with probe loss failovers within 10 secs."
}