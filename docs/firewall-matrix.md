# Firewall matrix

Router-enforced nftables policy on NixOS. VLAN design: [vlan-plan.md](vlan-plan.md).

**Default posture:** DENY inter-zone unless explicitly allowed. ALLOW established/related return traffic.

## Zone summary

| Zone | VLAN | Internet | Notes |
|------|------|----------|-------|
| mgmt | 10 | As needed for updates | Admin/BMC only |
| trusted | 20 | ALLOW | User devices |
| servers | 30 | ALLOW | Homelab hosts |
| iot | 40 | ALLOW (filtered DNS) | No LAN initiate |
| guest | 50 | ALLOW | No RFC1918 |
| wan | — | — | Inbound deny except listed |

## Inter-zone rules

| # | Source | Destination | Ports / proto | Action | Notes |
|---|--------|-------------|---------------|--------|-------|
| 1 | iot (40) | RFC1918 (any) | all | **DENY** | Prevents lateral movement |
| 2 | servers `10.10.30.20` | iot (40) | tcp/udp | **ALLOW** | Home Assistant → devices |
| 3 | iot (40) | servers | all new | **DENY** | Return traffic: ALLOW established,related |
| 4 | iot (40) | internet | tcp/udp | **ALLOW** | DNS only via Blocky `10.10.30.21` |
| 5 | iot (40) | `10.10.30.21` | 53, 853 | **ALLOW** | Blocky DNS |
| 6 | iot (40) | other DNS | 53, 853 | **DENY** | Force Blocky path |
| 7 | guest (50) | RFC1918 | all | **DENY** | Guest isolation |
| 8 | guest (50) | internet | tcp/udp | **ALLOW** | Public DNS (1.1.1.1 / 9.9.9.9) |
| 9 | trusted (20) | servers (30) | tcp/udp | **ALLOW** | Includes HA `:8123`, admin UIs |
| 10 | trusted (20) | iot cast targets | see below | **ALLOW** | Specific IPs only — not whole /24 |
| 11 | trusted (20) | `10.10.30.20` | 22/tcp | **ALLOW** | Forgejo SSH (LAN) |
| 12 | vpn (`10.10.255.0/24`) | trusted + servers + mgmt | tcp/udp | **ALLOW** | WireGuard peers |
| 13 | servers (30) | internet | tcp/udp | **ALLOW** | |
| 14 | mgmt (10) | servers (30) | as needed | **ALLOW** | BMC → nodes for provisioning |
| 15 | any internal | wan | all | **ALLOW** | NAT outbound |

### Trusted → IoT cast targets (optional, enable if discovery fails)

| Target | IP | Ports (typical) |
|--------|-----|-----------------|
| Samsung TV | `10.10.40.10` | UDP 1900, TCP 8008–8009 |
| Chromecast | `10.10.40.16` | UDP 5353, TCP 8008–8009 |
| Odyssey Smart Monitor | `10.10.40.15` | Per Samsung app |

**Deferred:** Nintendo Switch local wireless play (trusted ↔ `10.10.40.14`) — add only if needed.

## WAN inbound

| Source | Destination | Ports | Action | Notes |
|--------|-------------|-------|--------|-------|
| internet | `10.10.30.20` | 443/tcp, 80/tcp | **ALLOW** | Caddy only (Stage 7+) |
| internet | router | WireGuard UDP (e.g. 51820) | **ALLOW** | VPN |
| internet | any LAN | 22/tcp | **DENY** | No WAN SSH |
| trusted (20) | router | 22/tcp | **ALLOW** | Only VLAN that may SSH to router |
| mgmt / servers / iot / guest / vpn | router | 22/tcp | **DENY** | SSH locked to trusted (VPN TBD Stage 6) |
| internet | any LAN | *other* | **DENY** | Default deny |
| internet (v6) | any | * | **DENY** | Default deny; open per-service if needed |

## East-west (VLAN 30)

| Source | Destination | Ports | Action | Notes |
|--------|-------------|-------|--------|-------|
| `10.10.30.20` (Caddy) | `10.10.30.100` (Traefik LB) | 80/tcp | **ALLOW** | Caddy → k8s |
| trusted + vpn | router LAN | 11443/tcp | **ALLOW** | UniFi OS Server UI |
| AP (mgmt / native) | router LAN | 8080/tcp, 3478/udp, 10001/udp | **ALLOW** | UniFi inform / STUN / discovery (INPUT on router) |
| iot, guest | `10.10.30.20` | all | **DENY** | |
| iot, guest | k8s nodes / API | all | **DENY** | |
| trusted + vpn | k8s API `10.10.30.11:6443` | 6443/tcp | **ALLOW** | kubectl from trusted |
| wan | Traefik LB, k8s nodes | all | **DENY** | No direct WAN → cluster |

## Home Assistant (canonical rules)

| Rule | Action |
|------|--------|
| HA (`10.10.30.20`) → IoT device IPs | **ALLOW** tcp/udp |
| IoT → HA UI `:8123` | **DENY** |
| Trusted + VPN → HA `:8123` | **ALLOW** |
| IoT → HA (new sessions) | **DENY**; return: established,related |

## Implementation notes

- Disable **UPnP/NAT-PMP** on router.
- **Hairpin NAT:** Optional. Split-horizon DNS sends internal clients to `10.10.30.20` directly, so testing `https://zdk.no` from LAN does not require hairpin. Enable only if a client resolves the public IP from inside the network.
- Export rule intent to `router/modules/firewall.nix`; validate in Stage 4.
