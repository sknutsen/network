# CRS310-8G+2S+IN — L2 VLAN filter (RouterOS 7). No inter-VLAN routing.
# Idempotent: safe to /import on a live switch or after a no-defaults reset.
# See switch/README.md.

/system identity set name=crs310

/interface bridge
:do { add name=bridge vlan-filtering=yes frame-types=admit-only-vlan-tagged comment="cpu: tagged only" } on-error={
  set [find where name=bridge] vlan-filtering=yes frame-types=admit-only-vlan-tagged comment="cpu: tagged only"
}

/interface ethernet
set [find where default-name=ether7] disabled=yes
set [find where default-name=ether8] disabled=yes
set [find where default-name=sfp-sfpplus1] disabled=yes
set [find where default-name=sfp-sfpplus2] disabled=yes

/interface bridge port
:do { remove [find where interface=ether7] } on-error={}
:do { remove [find where interface=ether8] } on-error={}
:do { add bridge=bridge interface=ether1 pvid=1 frame-types=admit-only-vlan-tagged comment="janus trunk" } on-error={
  set [find where interface=ether1] bridge=bridge pvid=1 frame-types=admit-only-vlan-tagged comment="janus trunk"
}
:do { add bridge=bridge interface=ether2 pvid=10 frame-types=admit-all comment="U7 Lite native mgmt 10" } on-error={
  set [find where interface=ether2] bridge=bridge pvid=10 frame-types=admit-all comment="U7 Lite native mgmt 10"
}
:do { add bridge=bridge interface=ether3 pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="Turing Pi" } on-error={
  set [find where interface=ether3] bridge=bridge pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="Turing Pi"
}
:do { add bridge=bridge interface=ether4 pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="TrueNAS" } on-error={
  set [find where interface=ether4] bridge=bridge pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="TrueNAS"
}
:do { add bridge=bridge interface=ether5 pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="Zpi" } on-error={
  set [find where interface=ether5] bridge=bridge pvid=30 frame-types=admit-only-untagged-and-priority-tagged comment="Zpi"
}
:do { add bridge=bridge interface=ether6 pvid=10 frame-types=admit-all comment="USW-NC native mgmt 10" } on-error={
  set [find where interface=ether6] bridge=bridge pvid=10 frame-types=admit-all comment="USW-NC native mgmt 10"
}

# Replace the VLAN table. set [find vlan-ids=...] is unreliable (list-typed
# property; add-on-error then set *0). ether6 must leave VLAN 20 untagged
# before it can be untagged on VLAN 10 — wipe-and-add avoids that conflict.
/interface bridge vlan
:foreach v in=[find] do={ :do { remove $v } on-error={} }
add bridge=bridge vlan-ids=10 tagged=bridge,ether1 untagged=ether2,ether6 comment="mgmt"
add bridge=bridge vlan-ids=20 tagged=ether1,ether2,ether6 comment="trusted"
add bridge=bridge vlan-ids=30 tagged=ether1 untagged=ether3,ether4,ether5 comment="servers"
add bridge=bridge vlan-ids=40 tagged=ether1,ether2,ether6 comment="iot"
add bridge=bridge vlan-ids=50 tagged=ether1,ether2 comment="guest"

/interface vlan
:do { add interface=bridge name=vlan10 vlan-id=10 comment="switch mgmt" } on-error={
  set [find where name=vlan10] interface=bridge vlan-id=10 comment="switch mgmt"
}

/ip address
:do { add address=10.10.10.2/24 interface=vlan10 comment="crs310.lab.zdk.no" } on-error={
  set [find where comment="crs310.lab.zdk.no"] address=10.10.10.2/24 interface=vlan10
}

/ip route
:do { add dst-address=0.0.0.0/0 gateway=10.10.10.1 } on-error={
  set [find where dst-address=0.0.0.0/0] gateway=10.10.10.1
}

/ip dns
set servers=10.10.10.1

/ip service
set [find where name="telnet" and !dynamic] disabled=yes
set [find where name="ftp" and !dynamic] disabled=yes
set [find where name="www" and !dynamic] disabled=yes
set [find where name="api" and !dynamic] disabled=yes
set [find where name="api-ssl" and !dynamic] disabled=yes
:do { set [find where name="ssh" and !dynamic] available-from=10.10.10.0/24,10.10.20.0/24 } on-error={
  set [find where name="ssh" and !dynamic] address=10.10.10.0/24,10.10.20.0/24
}
:do { set [find where name="winbox" and !dynamic] available-from=10.10.10.0/24,10.10.20.0/24 } on-error={
  set [find where name="winbox" and !dynamic] address=10.10.10.0/24,10.10.20.0/24
}

/ip neighbor discovery-settings
set discover-interface-list=none

/tool mac-server
set allowed-interface-list=none

/tool mac-server mac-winbox
set allowed-interface-list=none

# CPU stays IPv4-only. Bridge still forwards IPv6 for clients (L2).
/ipv6 settings
set disable-ipv6=yes
