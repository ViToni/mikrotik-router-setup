# Setting up a MikroTik as default router

## Introduction

There are many good routers for consumer households.
The decision to use a [MikroTik](https://mikrotik.com) router, which you would be more likely to find in a network lab, was based on previous exposure and the intention to reduce the total number of devices.
It could have been custom hardware with [PFsense](https://www.pfsense.org/) or [OPNsense](https://opnsense.org/) on top, but since the network will also have WiFi meshing in the future, the MikroTik router can act directly as a coordinator (for MikroTik APs) without the need for another device, and the solution is hopefully also more power-efficient than a dedicated mini-PC.

Custom routing solutions like MikroTik routers can be configured down to the smallest detail, but it is easy to get lost in these details, especially if the configuration is not done on a daily basis.

This documentation is mainly intended to serve me as a reference for the configuration steps carried out (and why they were necessary / useful), but perhaps it could be helpful for others as well.

## Prerequisites

Internet connection: Telekom with BNG and MagentaTV

* Existing setup
  * [AVM Fritz!Box 4040](https://avm.de/produkte/fritzbox/fritzbox-4040/) as router
  * [Zyxel VMG1312-B30A](https://www.zyxel.com/de/de/products/dsl-cpe/wireless-n-vdsl2-4-port-gateway-with-usb-vmg1312-b30a) as external modem (VDSL2 and also taking care of VLAN 07 tagging)
  * Network: `10.0.0.0/16`
  * DHCP
    * Static leases (and IP-addresses) for well-known hosts
    * Dynamic IP-addresses for guests (range: `10.0.234.0/24`)

* New router: [RB5009UG+S+IN](https://mikrotik.com/product/rb5009ug_s_in)
  * will reuse the existing modem until fiber gets installed
  * when fiber is available, the SFP port will carry the GPON SFP module
