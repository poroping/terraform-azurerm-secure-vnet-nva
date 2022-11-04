<!-- BEGIN_TF_DOCS -->
# terraform-azurerm-secure-vnet-nva
The following module will spin up the infrastructure needed to simplify Azure network routing and allow routing towards the VNETs to be controlled by an NVA of your choice. This could be a Firewall/Router/SDWAN device.

## Caveats
- The NVA must support BGP
- The NVA must support eBGP multihop
- Traffic between VNETs will route via the NVA
- Traffic within the VNET will *not* route via the NVA
- The NVA pair should be able to deal with asymmetric routing

### NVA configuration
- Suggest keeping the advertisement interval short so routing changes are pushed down to the VNETs quickly or add summary routes to the NVA. An alternative is to have the NVA advertise the routes with the ILB frontend IP as the next hop.
- If routing is required between more than one RouteServer this must be done via the NVAs.
- You may also need to manipulate the AS path of routes from the RouteServers so that the same ASN doesn't appear twice from separate AS.
- This is due to BGPs route-loop prevention and Azure's inflexibility in setting the ASN used by the RouteServer.

### Example Usage:
```hcl
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
  source  = "poroping/secure-vnet-nva/azurerm"
  version = "~> 0.0.1"

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

  # module options
  create_sslvpn        = false
  assign_global_reader = false
  use_ilb              = false

}

output "fortigate_public_ips" {
  value = module.azure_fortigate_pair.nva_public_ips
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
# NVA MGMT interface will be accessible on port 10443 from list of trusted hosts.
```

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.0.2 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_nva_type"></a> [nva\_type](#input\_nva\_type) | Type of NVA. Valid options: `fortigate` | `string` | n/a | yes |
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | API key to cloudinit NVA with. | `string` | `null` | no |
| <a name="input_assign_global_reader"></a> [assign\_global\_reader](#input\_assign\_global\_reader) | Assign NVA system identity Global Reader in the subscription NVA is created in. Useful for NVAs that can access Azure metadata to create dynamic objects etc. Requires the Service Principal permissions to modify Roles. | `bool` | `false` | no |
| <a name="input_availability_zone_support"></a> [availability\_zone\_support](#input\_availability\_zone\_support) | Availability zone support. Ensure region supports this feature. | `bool` | `false` | no |
| <a name="input_create_sslvpn"></a> [create\_sslvpn](#input\_create\_sslvpn) | Create an ELB and required resources to bootstrap an SSLVPN service. | `bool` | `true` | no |
| <a name="input_fortigate_licenses"></a> [fortigate\_licenses](#input\_fortigate\_licenses) | Licenses for BYOL Fortigates. If not set will use PAYG. | `list(string)` | `null` | no |
| <a name="input_fortigate_sku"></a> [fortigate\_sku](#input\_fortigate\_sku) | If SKU changes can overwrite here otherwise can leave as default. | <pre>object({<br>    byol = string<br>    payg = string<br>  })</pre> | <pre>{<br>  "byol": "fortinet_fg-vm",<br>  "payg": "fortinet_fg-vm_payg_20190624"<br>}</pre> | no |
| <a name="input_fortios_version"></a> [fortios\_version](#input\_fortios\_version) | Target FortiOS version image. | `string` | `"latest"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for resources. | `string` | `"North Europe"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for Azure resource names. | `string` | `"secure-transit"` | no |
| <a name="input_nva_bgp_asn"></a> [nva\_bgp\_asn](#input\_nva\_bgp\_asn) | BGP ASN for NVA. | `number` | `65514` | no |
| <a name="input_password"></a> [password](#input\_password) | Initial password for admin access. | `string` | `"Solarwinds123!"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Full name for Azure resource group. | `string` | `"rsg-fortigate-testing"` | no |
| <a name="input_trusted_hosts"></a> [trusted\_hosts](#input\_trusted\_hosts) | Set of CIDRs to add to NSG for management access to NVA. | <pre>set(object({<br>    prefix   = string<br>    name     = string<br>    priority = number<br>  }))</pre> | `[]` | no |
| <a name="input_use_ilb"></a> [use\_ilb](#input\_use\_ilb) | Create an internal load balancer. Intention is to allow the NVA to advertise BGP routes towards the Route Server with the ILB frontend address as the next-hop. ILB should deal with probe loss failovers within 10 secs. | `bool` | `false` | no |
| <a name="input_username"></a> [username](#input\_username) | Initial username for admin access. | `string` | `"fortinet"` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Azure VM SKU | `string` | `"Standard_D2ds_v5"` | no |
| <a name="input_vnet_prefix"></a> [vnet\_prefix](#input\_vnet\_prefix) | Prefix for transit VNET. Will be broken into 4 equal subnets. | `string` | `"10.255.0.0/22"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_elb_public_ip"></a> [elb\_public\_ip](#output\_elb\_public\_ip) | Public IP assigned to ELB for SSLVPN. |
| <a name="output_external_interfaces"></a> [external\_interfaces](#output\_external\_interfaces) | n/a |
| <a name="output_external_subnet_prefix"></a> [external\_subnet\_prefix](#output\_external\_subnet\_prefix) | Transit VNET external subnet prefix. |
| <a name="output_internal_interfaces"></a> [internal\_interfaces](#output\_internal\_interfaces) | n/a |
| <a name="output_internal_subnet_prefix"></a> [internal\_subnet\_prefix](#output\_internal\_subnet\_prefix) | Transit VNET internal subnet prefix. |
| <a name="output_nva_public_ips"></a> [nva\_public\_ips](#output\_nva\_public\_ips) | NVA public IP addresses |
| <a name="output_resource_group"></a> [resource\_group](#output\_resource\_group) | n/a |
| <a name="output_route_server_ips"></a> [route\_server\_ips](#output\_route\_server\_ips) | RouteServer IP addresses. |
| <a name="output_rsg_name"></a> [rsg\_name](#output\_rsg\_name) | Name of created resource group. |
| <a name="output_transit_vnet_id"></a> [transit\_vnet\_id](#output\_transit\_vnet\_id) | Transit VNET ID. |
| <a name="output_transit_vnet_name"></a> [transit\_vnet\_name](#output\_transit\_vnet\_name) | Transit VNET name. |
<!-- END_TF_DOCS -->    