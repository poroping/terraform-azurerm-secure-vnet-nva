resource "azurerm_public_ip" "elb_pip" {
  count = var.create_sslvpn ? 1 : 0

  name                = "${local.nva.name_prefix}-nva-elb-pip"
  resource_group_name = azurerm_resource_group.rsg.name
  location            = azurerm_resource_group.rsg.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_lb" "elb" {
  count = var.create_sslvpn ? 1 : 0

  name                = "${local.nva.name_prefix}-nva-elb"
  location            = azurerm_resource_group.rsg.location
  resource_group_name = azurerm_resource_group.rsg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${local.nva.name_prefix}-elb-external-address"
    public_ip_address_id = azurerm_public_ip.elb_pip[0].id
  }
}

resource "azurerm_lb_backend_address_pool" "elb_backend" {
  count = var.create_sslvpn ? 1 : 0

  loadbalancer_id = azurerm_lb.elb[0].id
  name            = "${local.nva.name_prefix}-nva-elb-backend"
}

resource "azurerm_network_interface_backend_address_pool_association" "nvaelb_backendpool" {
  count = var.create_sslvpn ? 2 : 0

  network_interface_id    = azurerm_network_interface.nva_vm_external[count.index].id
  ip_configuration_name   = azurerm_network_interface.nva_vm_external[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.elb_backend[0].id
}

resource "azurerm_lb_probe" "nva_elb_probe" {
  count = var.create_sslvpn ? 1 : 0

  # resource_group_name = azurerm_resource_group.rsg.name
  loadbalancer_id = azurerm_lb.elb[0].id
  name            = "elb-nva-probe"
  port            = 8008
}

resource "azurerm_lb_rule" "elb_rule_http" {
  count = var.create_sslvpn ? 1 : 0

  # resource_group_name            = azurerm_resource_group.rsg.name
  loadbalancer_id                = azurerm_lb.elb[0].id
  name                           = "ELB-SSLVPN-HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.elb[0].frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.nva_elb_probe[0].id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.elb_backend[0].id]
  enable_floating_ip             = true
  load_distribution              = "SourceIP"
}

resource "azurerm_lb_rule" "elb_rule_https" {
  count = var.create_sslvpn ? 1 : 0

  # resource_group_name            = azurerm_resource_group.rsg.name
  loadbalancer_id                = azurerm_lb.elb[0].id
  name                           = "ELB-SSLVPN-HTTPS"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = azurerm_lb.elb[0].frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.nva_elb_probe[0].id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.elb_backend[0].id]
  enable_floating_ip             = true
  load_distribution              = "SourceIP"
}

data "azurerm_public_ip" "elb_pip" {
  count = var.create_sslvpn ? 1 : 0

  resource_group_name = azurerm_resource_group.rsg.name
  name                = azurerm_public_ip.elb_pip[0].name
}

