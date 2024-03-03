#| Welcome to RouterOS!
#|    1) Set a strong router password in the System > Users menu
#|    2) Upgrade the software in the System > Packages menu
#|    3) Enable firewall on untrusted networks
#| -----------------------------------------------------------------------------
#| RouterMode:
#|  * WAN port is protected by firewall and enabled DHCP client
#|  * Ethernet interfaces (except WAN port/s) are part of LAN bridge
#| LAN Configuration:
#|     IP address 192.168.88.1/24 is set on bridge (LAN port)
#|     DHCP Server: enabled;
#|     DNS: enabled;
#| WAN (gateway) Configuration:
#|     gateway:       ether1;
#|     ip4 firewall:  enabled;
#|     ip6 firewall:  enabled;
#|     NAT:   enabled;
#|     DHCP Client: enabled;
#| Login
#|     admin user protected by password

:global defconfMode;
:log info "Starting defconf script";
#-------------------------------------------------------------------------------
# Apply configuration.
# these commands are executed after installation or configuration reset
#-------------------------------------------------------------------------------
:if ($action = "apply") do={
  # wait for interfaces
  :local count 0;
  :while ([/interface ethernet find] = "") do={
    :if ($count = 30) do={
      :log warning "DefConf: Unable to find ethernet interfaces";
      /quit;
    }
    :delay 1s; :set count ($count +1); 
  };
  /interface list add name=WAN comment="defconf"
  /interface list add name=LAN comment="defconf"
  /interface bridge
    add name=bridge disabled=no auto-mac=yes protocol-mode=rstp comment=defconf;
  :local bMACIsSet 0;
  :foreach k in=[/interface find where !(slave=yes   || name="ether1" || passthrough=yes || type=loopback || name~"bridge")] do={
    :local tmpPortName [/interface get $k name];
    :if ($bMACIsSet = 0) do={
      :if ([/interface get $k type] = "ether") do={
        /interface bridge set "bridge" auto-mac=no admin-mac=[/interface get $tmpPortName mac-address];
        :set bMACIsSet 1;
      }
    }
      :if (([/interface get $k type] != "ppp-out") && ([/interface get $k type] != "lte")) do={
        /interface bridge port
          add bridge=bridge interface=$tmpPortName comment=defconf;
      }
    }
    /ip pool add name="default-dhcp" ranges=192.168.88.10-192.168.88.254;
    /ip dhcp-server
      add name=defconf address-pool="default-dhcp" interface=bridge lease-time=10m disabled=no;
    /ip dhcp-server network
      add address=192.168.88.0/24 gateway=192.168.88.1 dns-server=192.168.88.1 comment="defconf";
  /ip address add address=192.168.88.1/24 interface=bridge comment="defconf";
  /ip dns {
      set allow-remote-requests=yes
      static add name=router.lan address=192.168.88.1 comment=defconf
  }

    /ip dhcp-client add interface=ether1 disabled=no comment="defconf";
  /interface list member add list=LAN interface=bridge comment="defconf"
  /interface list member add list=WAN interface=ether1 comment="defconf"
  /ip firewall nat add chain=srcnat out-interface-list=WAN ipsec-policy=out,none action=masquerade comment="defconf: masquerade"
  /ip firewall {
    filter add chain=input action=accept connection-state=established,related,untracked comment="defconf: accept established,related,untracked"
    filter add chain=input action=drop connection-state=invalid comment="defconf: drop invalid"
    filter add chain=input action=accept protocol=icmp comment="defconf: accept ICMP"
    filter add chain=input action=accept dst-address=127.0.0.1 comment="defconf: accept to local loopback (for CAPsMAN)"
    filter add chain=input action=drop in-interface-list=!LAN comment="defconf: drop all not coming from LAN"
    filter add chain=forward action=accept ipsec-policy=in,ipsec comment="defconf: accept in ipsec policy"
    filter add chain=forward action=accept ipsec-policy=out,ipsec comment="defconf: accept out ipsec policy"
    filter add chain=forward action=fasttrack-connection connection-state=established,related comment="defconf: fasttrack"
    filter add chain=forward action=accept connection-state=established,related,untracked comment="defconf: accept established,related, untracked"
    filter add chain=forward action=drop connection-state=invalid comment="defconf: drop invalid"
    filter add chain=forward action=drop connection-state=new connection-nat-state=!dstnat in-interface-list=WAN comment="defconf: drop all from WAN not DSTNATed"
  }
  /ipv6 firewall {
    address-list add list=bad_ipv6 address=::/128 comment="defconf: unspecified address"
    address-list add list=bad_ipv6 address=::1 comment="defconf: lo"
    address-list add list=bad_ipv6 address=fec0::/10 comment="defconf: site-local"
    address-list add list=bad_ipv6 address=::ffff:0:0/96 comment="defconf: ipv4-mapped"
    address-list add list=bad_ipv6 address=::/96 comment="defconf: ipv4 compat"
    address-list add list=bad_ipv6 address=100::/64 comment="defconf: discard only "
    address-list add list=bad_ipv6 address=2001:db8::/32 comment="defconf: documentation"
    address-list add list=bad_ipv6 address=2001:10::/28 comment="defconf: ORCHID"
    address-list add list=bad_ipv6 address=3ffe::/16 comment="defconf: 6bone"
    filter add chain=input action=accept connection-state=established,related,untracked comment="defconf: accept established,related,untracked"
    filter add chain=input action=drop connection-state=invalid comment="defconf: drop invalid"
    filter add chain=input action=accept protocol=icmpv6 comment="defconf: accept ICMPv6"
    filter add chain=input action=accept protocol=udp dst-port=33434-33534 comment="defconf: accept UDP traceroute"
    filter add chain=input action=accept protocol=udp dst-port=546 src-address=fe80::/10 comment="defconf: accept DHCPv6-Client prefix delegation."
    filter add chain=input action=accept protocol=udp dst-port=500,4500 comment="defconf: accept IKE"
    filter add chain=input action=accept protocol=ipsec-ah comment="defconf: accept ipsec AH"
    filter add chain=input action=accept protocol=ipsec-esp comment="defconf: accept ipsec ESP"
    filter add chain=input action=accept ipsec-policy=in,ipsec comment="defconf: accept all that matches ipsec policy"
    filter add chain=input action=drop in-interface-list=!LAN comment="defconf: drop everything else not coming from LAN"
    filter add chain=forward action=accept connection-state=established,related,untracked comment="defconf: accept established,related,untracked"
    filter add chain=forward action=drop connection-state=invalid comment="defconf: drop invalid"
    filter add chain=forward action=drop src-address-list=bad_ipv6 comment="defconf: drop packets with bad src ipv6"
    filter add chain=forward action=drop dst-address-list=bad_ipv6 comment="defconf: drop packets with bad dst ipv6"
    filter add chain=forward action=drop protocol=icmpv6 hop-limit=equal:1 comment="defconf: rfc4890 drop hop-limit=1"
    filter add chain=forward action=accept protocol=icmpv6 comment="defconf: accept ICMPv6"
    filter add chain=forward action=accept protocol=139 comment="defconf: accept HIP"
    filter add chain=forward action=accept protocol=udp dst-port=500,4500 comment="defconf: accept IKE"
    filter add chain=forward action=accept protocol=ipsec-ah comment="defconf: accept ipsec AH"
    filter add chain=forward action=accept protocol=ipsec-esp comment="defconf: accept ipsec ESP"
    filter add chain=forward action=accept ipsec-policy=in,ipsec comment="defconf: accept all that matches ipsec policy"
    filter add chain=forward action=drop in-interface-list=!LAN comment="defconf: drop everything else not coming from LAN"
  }
    /ip neighbor discovery-settings set discover-interface-list=LAN
    /tool mac-server set allowed-interface-list=LAN
    /tool mac-server mac-winbox set allowed-interface-list=LAN
  :if (!($keepUsers = "yes")) do={
    :if (!($defconfPassword = "" || $defconfPassword = nil)) do={
      /user set admin password=$defconfPassword
      :delay 0.5
      /user expire-password admin 
    }
  }
}
#-------------------------------------------------------------------------------
# Revert configuration.
# these commands are executed if user requests to remove default configuration
#-------------------------------------------------------------------------------
:if ($action = "revert") do={
  :if (!($keepUsers = "yes")) do={
    /user set admin password=""
    :delay 0.5
    /user expire-password admin 
  }
  /system routerboard mode-button set enabled=no
  /system routerboard mode-button set on-event=""
  /system script remove [find comment~"defconf"]
  /system health settings
  set fan-full-speed-temp=65C fan-target-temp=58C fan-min-speed-percent=12% fan-control-interval=30s
  /queue interface set [find default-queue=only-hardware-queue] queue=only-hardware-queue
  /queue type remove [find name=fq-codel-ethernet-default]
  /ip firewall filter remove [find comment~"defconf"]
  /ipv6 firewall filter remove [find comment~"defconf"]
  /ipv6 firewall address-list remove [find comment~"defconf"]
  /ip firewall nat remove [find comment~"defconf"]
  /interface list member remove [find comment~"defconf"]
  /interface detect-internet set detect-interface-list=none
  /interface detect-internet set lan-interface-list=none
  /interface detect-internet set wan-interface-list=none
  /interface detect-internet set internet-interface-list=none
  /interface list remove [find comment~"defconf"]
  /tool mac-server set allowed-interface-list=all
  /tool mac-server mac-winbox set allowed-interface-list=all
  /ip neighbor discovery-settings set discover-interface-list=!dynamic
    :local o [/ip dhcp-server network find comment="defconf"]
    :if ([:len $o] != 0) do={ /ip dhcp-server network remove $o }
    :local o [/ip dhcp-server find name="defconf" !disabled]
    :if ([:len $o] != 0) do={ /ip dhcp-server remove $o }
    /ip pool {
      :local o [find name="default-dhcp" ranges=192.168.88.10-192.168.88.254]
      :if ([:len $o] != 0) do={ remove $o }
    }
    :local o [/ip dhcp-client find comment="defconf"]
    :if ([:len $o] != 0) do={ /ip dhcp-client remove $o }
  /ip dns {
    set allow-remote-requests=no
    :local o [static find comment="defconf"]
    :if ([:len $o] != 0) do={ static remove $o }
  }
  /ip address {
    :local o [find comment="defconf"]
    :if ([:len $o] != 0) do={ remove $o }
  }
  :foreach iface in=[/interface ethernet find] do={
    /interface ethernet set $iface name=[get $iface default-name]
  }
  /interface bridge port remove [find comment="defconf"]
  /interface bridge remove [find comment="defconf"]
  /interface bonding remove [find comment="defconf"]
}
:log info Defconf_script_finished;
:set defconfMode;
