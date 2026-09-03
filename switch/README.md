# CRS310 (MikroTik)

L2-only access/trunk switch. Routing stays on janus. Full port plan (including UniFi Flex Minis and SW-O): [vlan-plan.md](../docs/vlan-plan.md).

**Native VLAN 10 on trunks to UniFi gear:** port 2 (U7 Lite) and port 6 (USW-NC) carry untagged VLAN 10 so those devices get mgmt addresses and can reach Inform `10.10.10.1`. AP SSIDs are tagged 20/40/50. The USW-NC uplink is tagged 20/40 only (no guest, no servers).

## Apply (RouterOS 7)

The script is **idempotent** — `/import` on a live switch updates ports/VLANs in place. A no-defaults reset is only needed for a blank device.

1. Copy `crs310.rsc` to the device (Winbox / `scp`).
2. `/import file-name=crs310.rsc`
3. First boot only: `/system reset-configuration no-defaults=yes skip-backup=yes`, then steps 1–2.

Mgmt address: `10.10.10.2/24` on VLAN 10 (**IPv4 only** — `disable-ipv6=yes` on the CPU). L2 still forwards IPv6 for clients. SSH/Winbox from `10.10.10.0/24` and trusted `10.10.20.0/24` (`available-from` on the static service rows).

## Ports

| Port | Interface | Mode | VLAN |
|------|-----------|------|------|
| 1 | ether1 | tagged trunk | 10,20,30,40,50 → janus |
| 2 | ether2 | native 10 + tagged 20,40,50 | U7 Lite |
| 3 | ether3 | access 30 | Turing Pi |
| 4 | ether4 | access 30 | TrueNAS |
| 5 | ether5 | access 30 | Zpi |
| 6 | ether6 | native 10 + tagged 20,40 | USW-NC (port 4) |
| 7–8 | ether7/8 | disabled | unused |
| 9–10 | sfp-sfpplus1/2 | disabled | unused |

Downstream of ether6: USW-NC (closet) → USW-LR (living room, Hue/Trådfri) and SW-O (office, pingu + Peon). Flex Mini cannot use custom tagged profiles — **All** on trunks, a single network on access ports. See [vlan-plan.md](../docs/vlan-plan.md).
