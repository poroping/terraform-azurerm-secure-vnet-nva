resource "azurerm_virtual_hub" "transit_vhub" {
  name                = "${local.nva.name_prefix}-vhub"
  resource_group_name = azurerm_resource_group.rsg.name
  location            = azurerm_resource_group.rsg.location
  sku                 = "Standard"
}

resource "azurerm_public_ip" "vhub_pip" {
  name                = "${local.nva.name_prefix}-vhub-pip"
  location            = azurerm_resource_group.rsg.location
  resource_group_name = azurerm_resource_group.rsg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create a GatewaySubnet for future proofing and cause free
resource "azurerm_subnet" "gateway_snet" {
  name                 = "GatewaySubnet" # This name cannot be changed
  resource_group_name  = azurerm_resource_group.rsg.name
  virtual_network_name = azurerm_virtual_network.transit.name
  address_prefixes     = [local.nva.subnets[2]]
}

resource "azurerm_subnet" "transit_vhub" {
  name                 = "RouteServerSubnet" # This name cannot be changed
  resource_group_name  = azurerm_resource_group.rsg.name
  virtual_network_name = azurerm_virtual_network.transit.name
  address_prefixes     = [local.nva.subnets[3]]
}

resource "azurerm_virtual_hub_ip" "vhub_ip" {
  name                 = "${local.nva.name_prefix}-vhub-ip"
  virtual_hub_id       = azurerm_virtual_hub.transit_vhub.id
  public_ip_address_id = azurerm_public_ip.vhub_pip.id
  subnet_id            = azurerm_subnet.transit_vhub.id
}

resource "azurerm_virtual_hub_bgp_connection" "bgpconn" {
  count          = 2
  name           = "${local.nva.name_prefix}-vhub-bgpconnection-${count.index}"
  virtual_hub_id = azurerm_virtual_hub.transit_vhub.id
  peer_asn       = local.nva.bgp_asn
  peer_ip        = azurerm_network_interface.nva_vm_internal[count.index].private_ip_address

  depends_on = [azurerm_virtual_hub_ip.vhub_ip]
}