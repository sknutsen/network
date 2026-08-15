# Router OS and DHCP alternatives (reference)

**Chosen:** NixOS router + dnsmasq. See [decisions.md](../decisions.md).

## Router OS (not chosen)

| OS | Notes |
|----|-------|
| OPNsense/pfSense | Strong firewall UI; less declarative than NixOS |
| OpenWrt | Better for embedded; not ideal as homelab core router |

## DHCP (not chosen)

| | dnsmasq (chosen) | Kea |
|---|------------------|-----|
| Complexity | Low — per-VLAN config | JSON config, DHCPv4/v6 split |
| NixOS | `services.dnsmasq` | `services.kea` |
| When to reconsider | — | Advanced DHCPv6 beyond NixOS RA |

## DNS filtering (not chosen)

**AdGuard Home** — heavier, UI-centric. Blocky chosen for Git-friendly config.

## Caddy placement (rejected)

- Caddy on NixOS router
- Caddy in k8s hostNetwork
- RK1 LXC for edge

**Chosen:** Caddy on TrueNAS Docker only.

## Inter-VLAN routing (rejected)

**Router-on-a-stick** — single NIC carries WAN + VLAN trunk via 802.1Q subinterfaces. Works but shares one link. Rejected in favour of dedicated WAN (I217LM) + trunk (i350-T2).
