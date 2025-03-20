resource "azurerm_virtual_machine" "fortigate" {
  count = local.nva.type == "fortigate" ? 2 : 0

  name                             = "${local.nva.name_prefix}-${count.index}-vm-nva"
  location                         = azurerm_resource_group.rsg.location
  resource_group_name              = azurerm_resource_group.rsg.name
  network_interface_ids            = [azurerm_network_interface.nva_vm_internal[count.index].id, azurerm_network_interface.nva_vm_external[count.index].id]
  primary_network_interface_id     = azurerm_network_interface.nva_vm_external[count.index].id
  vm_size                          = var.vm_size
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true
  availability_set_id              = var.availability_zone_support == true ? null : azurerm_availability_set.nva_availability_set[0].id
  zones                            = var.availability_zone_support == true ? ["${count.index + 1}"] : null

  identity {
    type = "SystemAssigned"
  }

  storage_image_reference {
    publisher = "fortinet"
    offer     = "fortinet_fortigate-vm_v5"
    sku       = var.fortigate_licenses == null ? var.fortigate_sku["payg"] : var.fortigate_sku["byol"]
    version   = var.fortios_version
  }

  plan {
    publisher = "fortinet"
    product   = "fortinet_fortigate-vm_v5"
    name      = var.fortigate_licenses == null ? var.fortigate_sku["payg"] : var.fortigate_sku["byol"]
  }

  storage_os_disk {
    name              = "${local.nva.name_prefix}-${count.index}-vm-nva-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.nva.name_prefix}-${count.index}-vm-nva"
    admin_username = var.username
    admin_password = var.password
    custom_data    = data.template_file.fortigate_custom_data[count.index].rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# tflint-ignore: terraform_required_providers
data "template_file" "fortigate_custom_data" {
  count = local.nva.type == "fortigate" ? 2 : 0

  template = file("${path.module}/fortigate.tpl")

  vars = {
    fortigate_vm_name         = upper("${local.nva.name_prefix}-${count.index}-vm-fortigate")
    fortigate_ha              = true
    fortigate_ha_peerip       = local.nva_ha_peer_ip[count.index]
    fortigate_license         = var.fortigate_licenses == null ? "" : var.fortigate_licenses[count.index]
    fortigate_ssh_public_key  = null
    fortigate_external_ipaddr = azurerm_network_interface.nva_vm_external[count.index].private_ip_address
    fortigate_external_mask   = cidrnetmask(azurerm_subnet.transit_external.address_prefixes[0])
    fortigate_external_gw     = cidrhost(azurerm_subnet.transit_external.address_prefixes[0], 1)
    fortigate_internal_ipaddr = azurerm_network_interface.nva_vm_internal[count.index].private_ip_address
    fortigate_internal_mask   = cidrnetmask(azurerm_subnet.transit_internal.address_prefixes[0])
    fortigate_internal_gw     = cidrhost(azurerm_subnet.transit_internal.address_prefixes[0], 1)
    apikey                    = var.api_key == null ? random_password.apikey[0].result : var.api_key
    ha_enc_psk                = random_password.haenc.result
    ha_memberid               = count.index + 1
    elb                       = var.create_sslvpn == true ? var.create_sslvpn : false
    elb_ip                    = var.create_sslvpn == true ? azurerm_public_ip.elb_pip[0].ip_address : false
    route_server_1            = cidrhost(azurerm_subnet.transit_vhub.address_prefixes[0], 4)
    route_server_2            = cidrhost(azurerm_subnet.transit_vhub.address_prefixes[0], 5)
    bgp_asn                   = local.nva.bgp_asn
    bgp_offset                = -4000
    routerid                  = azurerm_public_ip.nva_pip[count.index].ip_address
    ilb                       = var.use_ilb
    ilb_ip                    = var.use_ilb == true ? azurerm_lb.ilb[0].private_ip_address : false
  }
}

data "azurerm_subscription" "primary" {
  count = var.assign_global_reader ? 1 : 0
}

resource "azurerm_role_assignment" "global_reader" {
  count = var.assign_global_reader ? 2 : 0

  scope                = data.azurerm_subscription.primary[0].id
  role_definition_name = "Reader"
  principal_id         = azurerm_virtual_machine.fortigate[count.index].identity.0.principal_id
}
