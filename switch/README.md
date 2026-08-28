# CRS310 (MikroTik)

L2-only access/trunk switch. Routing stays on janus. Port plan: [vlan-plan.md](../docs/vlan-plan.md).

**Native VLAN on the AP trunk (port 2):** untagged VLAN 10 so the U7 Lite gets a mgmt address and can reach Inform `10.10.10.1`. SSIDs are tagged 20/40/50.

## Apply (RouterOS 7)

1. Reset without defaults: `/system reset-configuration no-defaults=yes skip-backup=yes`
2. Copy `crs310.rsc` to the device (Winbox / `scp`).
3. `/import file-name=crs310.rsc`

Mgmt address: `10.10.10.2/24` on VLAN 10 (**IPv4 only** — `disable-ipv6=yes` on the CPU). L2 still forwards IPv6 for clients. SSH/Winbox from `10.10.10.0/24` only.

## Ports

| Port | Interface | Mode | VLAN |
|------|-----------|------|------|
| 1 | ether1 | tagged trunk | 10,20,30,40,50 → janus |
| 2 | ether2 | native 10 + tagged 20,40,50 | U7 Lite |
| 3 | ether3 | access 30 | Turing Pi |
| 4 | ether4 | access 30 | TrueNAS |
| 5 | ether5 | access 30 | Zpi |
| 6 | ether6 | access 20 | Pingu |
| 7 | ether7 | access 40 | Hue |
| 8 | ether8 | access 40 | Trådfri |
| 9–10 | sfp-sfpplus1/2 | disabled | unused |
