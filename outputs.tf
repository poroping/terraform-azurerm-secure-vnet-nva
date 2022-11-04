# This file contains outputs from the module
# https://www.terraform.io/docs/configuration/outputs.html

output "nva_public_ips" {
  description = "NVA public IP addresses"
  value       = [azurerm_public_ip.nva_pip[0].ip_address, azurerm_public_ip.nva_pip[1].ip_address]
}

output "elb_public_ip" {
  description = "Public IP assigned to ELB for SSLVPN."
  value       = var.create_sslvpn ? data.azurerm_public_ip.elb_pip[0].ip_address : null
}

output "route_server_ips" {
  # note this is not returned as a datasource yet, it may be that these are incorrect
  description = "RouteServer IP addresses."
  value       = [cidrhost(azurerm_subnet.transit_vhub.address_prefixes[0], 4), cidrhost(azurerm_subnet.transit_vhub.address_prefixes[0], 5)]
}

output "transit_vnet_id" {
  description = "Transit VNET ID."
  value       = azurerm_virtual_network.transit.id
}

output "transit_vnet_name" {
  description = "Transit VNET name."
  value       = azurerm_virtual_network.transit.name
}

output "external_subnet_prefix" {
  description = "Transit VNET external subnet prefix."
  value       = azurerm_subnet.transit_external.address_prefixes[0]
}

output "internal_subnet_prefix" {
  description = "Transit VNET internal subnet prefix."
  value       = azurerm_subnet.transit_internal.address_prefixes[0]
}

output "rsg_name" {
  description = "Name of created resource group."
  value       = azurerm_resource_group.rsg.name
}

output "resource_group" {
  value = azurerm_resource_group.rsg
}

output "external_interfaces" {
  value = azurerm_network_interface.nva_vm_external
}

output "internal_interfaces" {
  value = azurerm_network_interface.nva_vm_internal
}