/**
* # terraform-azurerm-secure-vnet-nva
* The following module will spin up the infrastructure needed to simplify Azure network routing and allow routing towards the VNETs to be controlled by an NVA of your choice. This could be a Firewall/Router/SDWAN device.
* 
* -> As of initial release the only NVA option is a pair of Fortigates.
*
* ## Caveats
* - The NVA must support BGP
* - The NVA must support eBGP multihop
* - Traffic between VNETs will route via the NVA
* - Traffic within the VNET will *not* route via the NVA
* - The NVA pair should be able to deal with asymmetric routing
* 
* ### NVA configuration
* - Suggest keeping the advertisement interval short so routing changes are pushed down to the VNETs quickly or add summary routes to the NVA. An alternative is to have the NVA advertise the routes with the ILB frontend IP as the next hop.
* - If routing is required between more than one RouteServer this must be done via the NVAs.
* - You may also need to manipulate the AS path of routes from the RouteServers so that the same ASN doesn't appear twice from separate AS.
* - This is due to BGPs route-loop prevention and Azure's inflexibility in setting the ASN used by the RouteServer.
*
*/

terraform {
  required_version = "~> 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.2"
    }
  }
}
