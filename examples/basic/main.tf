terraform {
  required_version = "~> 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "azure_fortigate_pair" {
  source = "../.."

  location            = "North Europe"
  name_prefix         = "advpn-hub-01"
  resource_group_name = "rsg-dev-transit"
  vnet_prefix         = "10.255.0.0/22"
  nva_bgp_asn         = 64420
  nva_type            = "fortigate"

  username = "fortinet"
  password = "Fortin3t!"
  trusted_hosts = [
    {
      prefix   = "185.62.0.0/32",
      name     = "MGMT-JUMPER",
      priority = 150
    }
  ]
  create_sslvpn        = true
  assign_global_reader = true
}

output "fortigate_public_ips" {
  value = module.azure_fortigate_pair.nva_public_ips
}

output "elb_public_ip" {
  value = module.azure_fortigate_pair.elb_public_ip
}

## Dev vnet
## Create another vnet to connect to this transit vnet

resource "azurerm_resource_group" "devrsg" {
  name     = "rsg-dev-workload"
  location = "North Europe"
}

locals {
  dev_prefix  = "192.168.8.0/22"
  dev_subnets = cidrsubnets(local.dev_prefix, 2, 2, 2, 2)
}

resource "azurerm_virtual_network" "dev" {

  name                = "dev-vnet"
  address_space       = [local.dev_prefix]
  location            = azurerm_resource_group.devrsg.location
  resource_group_name = azurerm_resource_group.devrsg.name
}

resource "azurerm_subnet" "dev01" {

  name                 = "dev-snet-01"
  resource_group_name  = azurerm_resource_group.devrsg.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = [local.dev_subnets[0]]
}

## Connections

resource "azurerm_virtual_network_peering" "dev2transit" {
  name                         = "vnet-conn-dev2transit"
  resource_group_name          = azurerm_resource_group.devrsg.name
  virtual_network_name         = azurerm_virtual_network.dev.name
  remote_virtual_network_id    = module.azure_fortigate_pair.transit_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true # secret sauce

  depends_on = [
    module.azure_fortigate_pair # explicitly depend on module finishing to avoid no gateway error
  ]
}

# Sometimes this VNET connection seems to fail and not propogate the routes from the Route Server. 
# This only appears to be an issue when creating a new Route Server, an existing one will always rx the correct routes.
# Suspect it's race condition with the Route Server completing setup and the peering being completed too early.

resource "azurerm_virtual_network_peering" "transit2dev" {
  name                         = "vnet-conn-transit2dev"
  resource_group_name          = module.azure_fortigate_pair.rsg_name
  virtual_network_name         = module.azure_fortigate_pair.transit_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.dev.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true # secret sauce
}

# To validate we should now see this VNET prefix advertised to the NVA via BGP.