# CRS310-8G+2S+IN — L2 VLAN filter (RouterOS 7). No inter-VLAN routing.
# Import on a no-defaults reset. See switch/README.md.

/system identity set name=crs310

/interface bridge
add name=bridge vlan-filtering=yes frame-types=admit-only-vlan-tagged comment="cpu: tagged only"

/interface ethernet
set [ find default-name=sfp-sfpplus1 ] disabled=yes
set [ find default-name=sfp-sfpplus2 ] disabled=yes

/interface bridge port
add bridge=bridge interface=ether1 pvid=1 frame-types=admit-only-vlan-tagged comment="janus trunk"
add bridge=bridge interface=ether2 pvid=10 frame-types=admit-all comment="U7 Lite native mgmt 10"
add bridge=bridge interface=ether3 pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="Turing Pi"
add bridge=bridge interface=ether4 pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="TrueNAS"
add bridge=bridge interface=ether5 pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="Zpi"
add bridge=bridge interface=ether6 pvid=20 frame-types=admit-only-untagged-and-priority-tagged comment="Pingu"
add bridge=bridge interface=ether7 pvid=40 frame-types=admit-only-untagged-and-priority-tagged comment="Hue"
add bridge=bridge interface=ether8 pvid=40 frame-types=admit-only-untagged-and-priority-tagged comment="Tradfri"

/interface bridge vlan
add bridge=bridge vlan-ids=10 tagged=bridge,ether1 untagged=ether2 comment="mgmt"
add bridge=bridge vlan-ids=20 tagged=ether1,ether2 untagged=ether6 comment="trusted"
add bridge=bridge vlan-ids=30 tagged=ether1 untagged=ether3,ether4,ether5 comment="servers"
add bridge=bridge vlan-ids=40 tagged=ether1,ether2 untagged=ether7,ether8 comment="iot"
add bridge=bridge vlan-ids=50 tagged=ether1,ether2 comment="guest"

/interface vlan
add interface=bridge name=vlan10 vlan-id=10 comment="switch mgmt"

/ip address
add address=10.10.10.2/24 interface=vlan10 comment="crs310.lab.zdk.no"

/ip route
add dst-address=0.0.0.0/0 gateway=10.10.10.1

/ip dns
set servers=10.10.10.1

/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
set ssh address=10.10.10.0/24
set winbox address=10.10.10.0/24

/ip neighbor discovery-settings
set discover-interface-list=none

/tool mac-server
set allowed-interface-list=none

/tool mac-server mac-winbox
set allowed-interface-list=none

# CPU stays IPv4-only. Bridge still forwards IPv6 for clients (L2).
/ipv6 settings
set disable-ipv6=yes
