# Setting up a MikroTik as default router

Documentation for setting up MikroTik routers for use with Telekom / MagentaTV.

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
    * Telekom sells the [Digitalisierungsbox Glasfasermodem](https://geschaeftskunden.telekom.de/internet-dsl/produkt/digitalisierungsbox-glasfasermodem-kaufen) which is a [Zyxel PMG3000-D20B](https://hack-gpon.github.io/ont-zyxel-pmg3000-d20b/).
    This modem has a SC/APC socket, the wall box has a LC/APC socket. \
    (Some tutorials say one needs a `ONT-Anschlusskennung`, for me using the [modem ID](https://www.telekom.de/hilfe/festnetz-internet-tv/anschluss-verfuegbarkeit/anschlussvarianten/glasfaseranschluss/modem-id) during configuration was just fine. ONT might be required for business accounts though.)
    * Corning has [fiber cables in various lengths](https://www.amazon.de/dp/B09GRK3QG6) for a moderate price (but they have only 2 mm white cables, the 3 mm ones are yellow).

## PPPoE credentials

The regular Telekom-PPPoE user consists out of multiple parts derived from the contract data.

The full PPPoE username would be:

`AAAAAAAAAAAATTTTTTTTTTT#MMMM@t-online.de`

with

* **A** => Anschlusskennung
* **T** => T-Online-Nummer
* **M** => Mitbenutzernummer

(If the `AAAAAAAAAAAATTTTTTTTTTT` part is 24 characters long, the `#` character before the MMMM part can be omitted.)

## Default configuration of RB5009UG+S+IN

RouterOS (v7.6) comes with this [default configuration](scripts/mikrotik/default-configuration/script.rsc).

The default configuration script can be queried with this command

```RouterOS
/system/default-configuration/script print
```

or to show all default configuration scripts:

```RouterOS
/system/default-configuration print
```

### References

* MikroTik
  * [Default configurations](https://help.mikrotik.com/docs/display/ROS/Default+configurations)

## Setting up the basic network and connectivity

### Remove WAN interfaces from bridge

The SFP interface might become the new WAN device when using fiber.
As it is not used for the internal network it can be already removed.

```RouterOS
/interface bridge port
  remove [find interface=sfp-sfpplus1]

/interface list member
  add list=WAN interface=sfp-sfpplus1
```

### Setup using "Quick Set"

"Quick Set" helps with the initial setup, especially when the network address shall be changed.

|Setting                    |Value                      |Comment    |
|---------------------------|---------------------------|-----------|
|                           |                           |           |
|**Mode**                   |[x] Router                 |           |
|                           |                           |           |
|**Port**                   |`eth1`                     |           |
|**Address Acquisition**    |`PPPoE`                    |           |
|**PPPoE User**             |`...@t-online.de`          |           |
|**PPPoE Password**         |`12345678`                 |           |
|**PPPoE Service Name**     |`Telekom`                  |(optional) |
|                           |                           |           |
|**IP Address**             |`10.0.0.1`                 |           |
|**Netmask**                |`255.255.0.0/16`           |           |
|**Bridge All LAN Ports**   | [ ]                       |           |
|**DHCP Server**            | [x]                       |           |
|**DHCP Server Range**      |`10.0.234.1-10.0.234.254`  |           |
|**NAT**                    | [x]                       |           |

#### References

* MikroTik
  * [Manual - Quickset](https://wiki.mikrotik.com/wiki/Manual:Quickset)

### Manual setup

#### Setup of DHCP and IP range

The network is already set up with `192.168.88.1/24`. This snippet changes the respective addresses and ranges.

For consistency all these commands should be executed at once:

```RouterOS
/ip pool
  set [find name=default-dhcp] name=dhcp-LAN ranges=10.0.234.1-10.0.234.254

/ip dhcp-server
  set [find address-pool=default-dhcp] address-pool=default-LAN

/ip address
  set [find address=192.168.88.0/24] \
    address=10.0.0.0/16 \
    network=10.0.0.0 \
    interface=bridge

/ip dhcp-server network
  set [find address=192.168.88.0/24] \
    address=10.0.0.0/16 \
    netmask=16 \
    gateway=10.0.0.1 \
    dns-server=10.0.0.1

/ip dns static
  set [find address=192.168.88.1] \
    address=10.0.0.1 \
    name=router
```

##### References

* MikroTik
  * [IP Pools](https://help.mikrotik.com/docs/display/ROS/IP+Pools)
  * [IP Addressing - Adding IP Address](https://help.mikrotik.com/docs/display/ROS/IP+Addressing#IPAddressing-AddingIPAddress)
  * [DHCP-Network](https://help.mikrotik.com/docs/display/ROS/DHCP#DHCP-Network)
  * [DNS Static](https://help.mikrotik.com/docs/display/ROS/DNS#DNS-DNSStatic)

#### Create VLAN tagged interface for PPPoE

Set up a VLAN interface for the PPPoE client.
This is only required when the modem doesn't take care of tagging.

Depending on the modem, `interface` can be any of:

* `ether1` (external modem without VLAN tagging)
* `sfp-sfpplus1` (SFP modem without VLAN tagging)

```RouterOS
/interface vlan
  add interface=ether1 vlan-id=7 name=vlan07

/interface list member
  add list=WAN interface=vlan07
```

##### References

* MikroTik
  * [VLAN - Layer3 VLAN examples](https://help.mikrotik.com/docs/display/ROS/VLAN#VLAN-Layer3VLANexamples)

#### Configure PPPoE client

Depending on the modem configuration `interface` can be any of:

* `vlan07` (modem has no VLAN tagging)
* `ether1` (modem does VLAN tagging)
* `sfp-sfpplus1` (SFP modem does VLAN tagging)

```RouterOS
/interface pppoe-client
  add interface=vlan07 add-default-route=yes \
    use-peer-dns=yes \
    name=pppoe-out1 \
    user="AAAAAAAAAAAATTTTTTTTTTT#MMMM@t-online.de" \
    password="12345678"
```

##### References

* MikroTik
  * [First Time Configuration - PPPoE Connection](https://help.mikrotik.com/docs/display/ROS/First+Time+Configuration#FirstTimeConfiguration-PPPoEConnection)

## Extended network configuration

### Multicast / IPTV configuration

#### Set up IGMP proxy

```RouterOS
/routing igmp-proxy interface
  add interface=pppoe-out1 alternative-subnets=87.141.215.251/32 upstream=yes comment=MagentaTV
  add interface=bridge comment=MagentaTV
```

##### References

* MikroTik
  * [IGMP Proxy - Examples](https://help.mikrotik.com/docs/display/ROS/IGMP+Proxy#IGMPProxy-Examples)

#### Add IP range of multicast networks

```RouterOS
/ip firewall address-list
  add address=224.0.0.0/4   list=Multicast comment=MagentaTV
  add address=232.0.0.0/16  list=Multicast comment=MagentaTV
  add address=239.35.0.0/16 list=Multicast comment=MagentaTV
```

#### Add firewall rules to allow traffic from multicast networks

```RouterOS
/ip firewall filter
  add chain=input   action=accept dst-address-list=Multicast place-before=2 comment=MagentaTV
  add chain=forward action=accept dst-address-list=Multicast place-before=2 comment=MagentaTV
```

#### Activate IGMP snooping on bridge

```RouterOS
/interface bridge
  set [find where name=bridge and comment=defConf] \
    igmp-snooping=yes igmp-version=3 mld-version=2 multicast-router=permanent comment=MagentaTV
```

##### References

* MikroTik
  * [Basic IGMP snooping configuration](https://help.mikrotik.com/docs/pages/viewpage.action?pageId=59277403#BridgeIGMP/MLDsnooping-BasicIGMPsnoopingconfiguration)

#### Sources

* [Telekom Magenta TV/Entertain mit Mikrotik Router und VLANs](https://simon.taddiken.net/magenta-mikrotik/)
* [Mikrotik - Telekom Magenta TV - IPTV - Tutorial](https://administrator.de/tutorial/mikrotik-telekom-magenta-tv-iptv-tutorial-667348.html)

### Extended DHCP configuration

#### Add static DHCP leases

```RouterOS
/ip dhcp-server lease
  add client-id=1:22:33:44:55:66:77 mac-address=22:33:44:55:66:77 address=10.0.25.2 comment="Notebook-1"
  add client-id=1:12:23:34:45:56:67 mac-address=12:23:34:45:56:67 address=10.0.25.11 comment="Android-5"
```

Note:\
The `client-id` is required, otherwise the router seems to not persist the entry.
The `client-id` was calculated by using the prefix `1:` and the MAC of the device.

##### References

* MikroTik
  * [DHCP-Server / Leases](https://wiki.mikrotik.com/wiki/Manual:IP/DHCP_Server#Leases)
  * [DHCP / Leases](https://help.mikrotik.com/docs/display/ROS/DHCP#DHCP-Leases)

#### Add static DNS record for known hosts

```RouterOS
/ip dns static
  add name="Notebook-1" address=10.0.25.2
  add name="Android-5" address=10.0.25.11
```

##### References

* MikroTik
  * [Setting static DNS record for each DHCP lease](https://wiki.mikrotik.com/wiki/Setting_static_DNS_record_for_each_DHCP_lease)

#### Using existing data from Fritz!Box

Fritz!OS (tested with v7.29) provides an API to query data from the router.

This data can be reused to configure the MikroTik router.

The [Fritz2Tik](Fritz2Tik.md) documentation describes the details and steps needed to transform the data accordingly.

### Restricting time / bandwidth

RouterOS supports setting up online time / bandwidth restrictions for clients.
This functionality is called *Kid Control*.

#### References

* MikroTik
  * [Kid Control](https://help.mikrotik.com/docs/display/ROS/Kid+Control)

#### Creating profiles

```RouterOS
/ip kid-control
  add name=Time \
    mon=0s-1h,16h-1d \
    tue=0s-1h,16h-1d \
    wed=0s-1h,16h-1d \
    thu=0s-1h,16h-1d \
    fri=0s-1h,16h-1d \
    sat=0s-1h,12h-1d \
    sun=0s-1h,12h-1d
  add name=Time-Bandwidth \
    mon=0s-1h,16h-1d \
    tue=0s-1h,16h-1d \
    wed=0s-1h,16h-1d \
    thu=0s-1h,16h-1d \
    fri=0s-1h,16h-1d \
    sat=0s-1h,12h-1d \
    sun=0s-1h,12h-1d \
    rate-limit=70M
```

Note:\
For times up to midnight one has to use:
 * on the CLI: `1d` or `24h`
 * on web UI: `1d 00:00:00`

For times starting at `00:00:00` one has to use `0s` on the CLI.\
Even if the UI suggests it supports seconds (because they are shown), it does not.

#### Assign devices to profiles

```RouterOS
/ip kid-control device
  add mac-address=12:23:34:45:56:67 name=Android-5 user=Time
  add mac-address=22:33:44:55:66:77 name=Notebook-1 user=Time-Bandwidth
```

### Add access to modem

The modem resides behind the router and has its own address / network.
It's possible to access the modem with a few configuration adjustments.

#### External modem

The modem is reachable via `ether1` and has the address `192.168.1.1/24`.

Add NAT rule to the firewall for the modem interface:

```RouterOS
/ip firewall nat
  add action=masquerade chain=srcnat out-interface=ether1 \
    comment="Zyxel VMG1312-B30A"
```

Assign `ether1` a dedicated IP in the network range of the modem to allow routing:

```RouterOS
/ip address
  add address=192.168.1.2/24 interface=ether1 network=192.168.1.0 \
    comment="Zyxel VMG1312-B30A"
```

Assign the modem a name (so that one does not have to remember its network/IP):

```RouterOS
/ip dns static
  add address=192.168.1.1 name=modem comment="Zyxel VMG1312-B30A"
```

#### Internal SFP modem

The modem is reachable via `sfp-sfpplus1` and has the address `10.10.1.1/24`.

Add NAT rule to the firewall for the modem interface:

```RouterOS
/ip firewall nat
  add action=masquerade chain=srcnat out-interface=sfp-sfpplus1 \
    comment="Digitalisierungsbox Glasfasermodem"
```

Assign `sfp-sfpplus1` a dedicated IP in the network range of the modem to allow routing:

```RouterOS
/ip address
  add address=10.10.1.2/24 interface=sfp-sfpplus1 network=10.10.1.0 \
    comment="Digitalisierungsbox Glasfasermodem"
```

Assign the modem a name (so that one does not have to remember its network/IP):

```RouterOS
/ip dns static
  add address=sfp-sfpplus1 name=fiber-modem \
    comment="Digitalisierungsbox Glasfasermodem"
```

## Activate Internet detection

Applying this setting will make RouterOS try to detect the "Internet".

It's activated mostly to allow the mobile app to show some nice graphs about bandwidth usage...

As this feature might mix up interface lists (and by that firewall settings), it is safer to create interface lists solely for the purpose of Internet detection.

```RouterOS
/interface list
  add name=di-where-detect
  add name=di-detected-lan
  add name=di-detected-wan
  add name=di-detected-internet

/interface detect-internet
  set detect-interface-list=di-where-detect \
    lan-interface-list=di-detected-lan \
    wan-interface-list=di-detected-wan \
    internet-interface-list=di-detected-internet

/interface list member
  add interface=pppoe-out1 list=di-where-detect
```

### References

* MikroTik
  * [Detect Internet](https://help.mikrotik.com/docs/display/ROS/Detect+Internet)
  * [What is Detect Internet for?](https://forum.mikrotik.com/viewtopic.php?t=187814#p946990)

## Services

### Create & add SSL certificate for `web-ssl`

To start `web-ssl` one needs to create a certificate which can't be done solely on the MikroTik itself.

#### Sources

* [Create a Self-Signed Certificate on MikroTik](https://cyberjunky.nl/create-self-sign-cert-for-mikrotik/)

#### Step 1 - Create certificate request - MikroTik

```RouterOS
/certificate
  add name=SSL common-name=SSL key-size=2048
  create-certificate-request template=SSL key-passphrase=<passphrase of your choice>
```

#### Step 2 - Create self-signed certificate - System with OpenSSL installed

Copy the files to a system with `OpenSSL`.

```shell
openssl rsa -in certificate-request_key.pem -text > certificate-request2.pem
openssl x509 -req -days 9999 -in certificate-request.pem -signkey certificate-request2.pem -out mikrotik_ssl.crt
```

Upload the created files to the MikroTik.

#### Step 3 - Configure certificate - MikroTik

Configure the imported file as certificate.

```RouterOS
/certificate import file-name=mikrotik_ssl.crt
```

Output:

```RouterOS
passphrase: ******
     certificates-imported: 1
     private-keys-imported: 0
            files-imported: 0
       decryption-failures: 0
  keys-with-no-certificate: 0
```

#### Step 4 - Configure key - MikroTik

Configure the imported key file.

```RouterOS
/certificate import file-name=certificate-request2.pem
```

Output:

```RouterOS
passphrase: *****
     certificates-imported: 0
     private-keys-imported: 1
            files-imported: 1
       decryption-failures: 0
  keys-with-no-certificate: 0
```

#### Step 5 - Validate certificate - MikroTik

```RouterOS
/certificate print
```

Output:

```RouterOS
Flags: K - PRIVATE-KEY; T - TRUSTED
Columns: NAME, COMMON-NAME, FINGERPRINT
#    NAME                COMMON-NAME  FINGERPRINT
0    SSL                 SSL          abc...
1 KT mikrotik_ssl.crt_0  SSL          efg...
```

#### Step 6 - Configure and enable `web-ssl` - MikroTik

Configure `web-ssl` to use the certificate and enable the service:

```RouterOS
/ip service
  set [find name=www-ssl] certificate=mikrotik_ssl.crt_0 disabled=no
```

#### References

* MikroTik
  * [Certificates](https://help.mikrotik.com/docs/display/ROS/Certificates)

### Disable unused services

Keep `ssh`, `www` and `www-ssl` but disable service not used.

```RouterOS
/ip service
  set api     disabled=yes
  set api-ssl disabled=yes
  set ftp     disabled=yes
  set telnet  disabled=yes
```

## DNS Caveats

When switching from VDSL to fiber it might seem that the connection does not work properly.
The reason could be actually local DNS caching, here `www.heise.de` is resolved to `ip.block.dt.de`:

```sh
$ ping www.heise.de
PING ip.block.dt.de (46.29.100.42): 56 data bytes
64 bytes from 46.29.100.42: icmp_seq=0 ttl=52 time=29.764 ms
64 bytes from 46.29.100.42: icmp_seq=1 ttl=52 time=29.047 ms
64 bytes from 46.29.100.42: icmp_seq=2 ttl=52 time=29.401 ms
...
```

One can either reboot or flush the DNS cache:

### Flushing MikroTik DNS cache

```RouterOS
/ip dns cache flush
```

#### References

* MikroTik
  * [DNS Cache](https://help.mikrotik.com/docs/display/ROS/DNS#DNS-DNSCache)

### Flushing Linux DNS cache

```bash
sudo systemd-resolve --flush-caches
sudo resolvectl flush-caches
```

or when DNS resolution is using `dnsmasq`

```bash
sudo killall -HUP dnsmasq
```

### Flushing MacOS DNS cache

```zsh
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

### Flushing Windows DNS cache

```batch
ipconfig /flushdns
```
