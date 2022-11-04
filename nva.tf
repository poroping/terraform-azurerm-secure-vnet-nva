locals {
  nva = {
    name_prefix         = var.name_prefix
    resource_group_name = var.resource_group_name
    location            = var.location
    vnet_prefix         = var.vnet_prefix
    subnets             = cidrsubnets(var.vnet_prefix, 2, 2, 2, 2)
    bgp_asn             = var.nva_bgp_asn
    type                = var.nva_type
  }
}

resource "azurerm_resource_group" "rsg" {
  name     = local.nva.resource_group_name
  location = local.nva.location
}

resource "azurerm_virtual_network" "transit" {
  name                = "${local.nva.name_prefix}-transit-vnet"
  address_space       = [local.nva.vnet_prefix]
  location            = azurerm_resource_group.rsg.location
  resource_group_name = azurerm_resource_group.rsg.name
}

resource "azurerm_subnet" "transit_external" {
  name                 = "${local.nva.name_prefix}-transit-snet-external"
  resource_group_name  = azurerm_resource_group.rsg.name
  virtual_network_name = azurerm_virtual_network.transit.name
  address_prefixes     = [local.nva.subnets[1]]
}

resource "azurerm_subnet" "transit_internal" {
  name                 = "${local.nva.name_prefix}-transit-snet-internal"
  resource_group_name  = azurerm_resource_group.rsg.name
  virtual_network_name = azurerm_virtual_network.transit.name
  address_prefixes     = [local.nva.subnets[0]]
}

resource "azurerm_public_ip" "nva_pip" {
  count = 2

  name                = "${local.nva.name_prefix}-${count.index}-nva-pip"
  resource_group_name = azurerm_resource_group.rsg.name
  location            = azurerm_resource_group.rsg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zone_support == true ? [1, 2, 3] : null

  ip_tags = var.availability_zone_support == true ? {
    RoutingPreference = "Internet"
  } : null
}

resource "azurerm_availability_set" "nva_availability_set" {
  count = var.availability_zone_support == false ? 1 : 0

  name                        = "${local.nva.name_prefix}-nva-avail"
  location                    = azurerm_resource_group.rsg.location
  resource_group_name         = azurerm_resource_group.rsg.name
  platform_fault_domain_count = 2
}

resource "azurerm_network_interface" "nva_vm_internal" {
  count = 2

  name                          = "${local.nva.name_prefix}-${count.index}-internal-nic"
  resource_group_name           = azurerm_resource_group.rsg.name
  location                      = azurerm_resource_group.rsg.location
  enable_ip_forwarding          = true
  enable_accelerated_networking = true


  ip_configuration {
    name                          = "${local.nva.name_prefix}-${count.index}-internal-ip"
    subnet_id                     = azurerm_subnet.transit_internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# swap the ips for l3 ha sync
locals {
  nva_ha_peer_ip = [
    azurerm_network_interface.nva_vm_internal[1].private_ip_address,
    azurerm_network_interface.nva_vm_internal[0].private_ip_address
  ]
}

resource "azurerm_network_interface" "nva_vm_external" {
  count = 2

  name                          = "${local.nva.name_prefix}-${count.index}-external-nic"
  resource_group_name           = azurerm_resource_group.rsg.name
  location                      = azurerm_resource_group.rsg.location
  enable_ip_forwarding          = true
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "${local.nva.name_prefix}-${count.index}-external-ip"
    subnet_id                     = azurerm_subnet.transit_external.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nva_pip[count.index].id
  }
}

resource "azurerm_network_security_group" "nva_nsg_external" {
  name                = "${local.nva.name_prefix}-nsg-external"
  location            = azurerm_resource_group.rsg.location
  resource_group_name = azurerm_resource_group.rsg.name

  dynamic "security_rule" {
    for_each = var.trusted_hosts

    content {
      access                     = "Allow"
      direction                  = "Inbound"
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      protocol                   = "*"
      source_port_range          = "*"
      source_address_prefix      = security_rule.value.prefix
      destination_port_range     = "*"
      destination_address_prefix = "*"
    }
  }
  security_rule {
    access                     = "Deny"
    direction                  = "Inbound"
    name                       = "denymgmt"
    priority                   = 250
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "0.0.0.0/0"
    destination_port_range     = "10443"
    destination_address_prefix = "*"
  }
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "vpn"
    priority                   = 4000
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "0.0.0.0/0"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nva_external" {
  count = 2

  network_interface_id      = azurerm_network_interface.nva_vm_external[count.index].id
  network_security_group_id = azurerm_network_security_group.nva_nsg_external.id
}

resource "azurerm_lb" "ilb" {
  count = var.use_ilb == true ? 1 : 0

  name                = "${local.nva.name_prefix}-nva-ilb"
  location            = azurerm_resource_group.rsg.location
  resource_group_name = azurerm_resource_group.rsg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "${local.nva.name_prefix}-nva-ilb-frontend"
    zones                         = var.availability_zone_support == true ? [1, 2, 3] : null
    subnet_id                     = azurerm_subnet.transit_internal.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
  }
}

resource "azurerm_lb_backend_address_pool" "ilb_backend" {
  count = var.use_ilb ? 1 : 0

  loadbalancer_id = azurerm_lb.ilb[0].id
  name            = "${local.nva.name_prefix}-nva-ilb-backend"
}

resource "azurerm_network_interface_backend_address_pool_association" "nvailb_backendpool" {
  count = var.use_ilb ? 2 : 0

  network_interface_id    = azurerm_network_interface.nva_vm_internal[count.index].id
  ip_configuration_name   = azurerm_network_interface.nva_vm_internal[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.ilb_backend[0].id
}

resource "azurerm_lb_probe" "nva_ilb_probe" {
  count = var.use_ilb ? 1 : 0

  loadbalancer_id     = azurerm_lb.ilb[0].id
  name                = "ilb-nva-probe"
  port                = 8008
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "nva_ilb_ha" {
  count = var.use_ilb ? 1 : 0

  loadbalancer_id                = azurerm_lb.ilb[0].id
  name                           = "NVA-HA"
  frontend_ip_configuration_name = azurerm_lb.ilb[0].frontend_ip_configuration[0].name
  protocol                       = "All"
  idle_timeout_in_minutes        = 30
  probe_id                       = azurerm_lb_probe.nva_ilb_probe[0].id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.ilb_backend[0].id]
  enable_floating_ip             = true
  load_distribution              = "Default"
  frontend_port                  = 0
  backend_port                   = 0
}
