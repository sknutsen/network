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
| 4 | iot (40) | internet | tcp/udp | **ALLOW** | Classic DNS intercepted (6b); DoH `:443` still possible |
| 5 | iot (40) | `10.10.30.21` | 53, 853 | **ALLOW** | Blocky DNS (forward, including after DNAT) |
| 6 | iot (40) | other RFC1918 DNS | 53, 853 | **DENY** | Force Blocky path on LAN |
| 6a | iot (40) | router (any local IP) | 53, 853 | **DENY** after `enableBlocky`; **ALLOW** 53 before | Backup: prerouting DNAT usually rewrites these first. DHCP `:67` always |
| 6b | iot (40) | any dest DNS (v4) | 53, 853 | **DNAT** to Blocky `10.10.30.21` after `enableBlocky` | Hardcoded `8.8.8.8` etc. Conntrack restores the source IP on replies. **DoH `:443` cannot be redirected** |
| 6c | iot (40) | any dest DNS (v6) | 53, 853 | **DNAT** to `blockyIpv6` when `enableIpv6` + `enableBlocky` + GUA set | Same as 6b. If GUA is unset, IPv6 DNS to WAN is **dropped** (clients fall back to v4 intercept). No IPv6 masquerade |
| 7 | guest (50) | RFC1918 | all | **DENY** | Guest isolation |
| 8 | guest (50) | internet | tcp/udp | **ALLOW** | Public DNS (1.1.1.1 / 9.9.9.9) |
| 9 | trusted (20) | servers (30) | tcp/udp | **ALLOW** | Admin UIs; HA/Authelia/Forgejo HTTP on TrueNAS **dropped** (11a) |
| 10 | trusted (20) | iot cast targets | see below | **DEFERRED** Stage 4–5 | Commented in `firewall.nix` until HA/cast; specific IPs only |
| 11 | trusted (20) | `10.10.30.20` | 2222/tcp | **ALLOW** | Forgejo SSH (LAN); not `:22` (TrueNAS SSH) |
| 11a | any forward | `10.10.30.20` | 3000, 8123, 9091/tcp | **DENY** | Caddy on janus (OUTPUT) is the only client |
| 12 | vpn (`10.10.255.0/24`) | trusted + servers + mgmt | tcp/udp | **ALLOW** | WireGuard peers |
| 13 | servers (30) | internet | tcp/udp | **ALLOW** | |
| 14 | mgmt (10) | servers (30) | as needed | **ALLOW** | BMC → nodes for provisioning |
| 15 | any internal | wan | all | **ALLOW** | NAT outbound |

### Trusted → IoT cast targets (Stage 4–5 / HA — not Stage 3)

| Target | IP | Ports (typical) |
|--------|-----|-----------------|
| Samsung TV | `10.10.40.10` | UDP 1900, TCP 8008–8009 |
| Chromecast | `10.10.40.16` | UDP 5353, TCP 8008–8009 |
| Odyssey Smart Monitor | `10.10.40.15` | Per Samsung app |

**Deferred:** Nintendo Switch local wireless play (trusted ↔ `10.10.40.14`) — add only if needed.

## WAN inbound

| Source | Destination | Ports | Action | Notes |
|--------|-------------|-------|--------|-------|
| ISP DHCP server | router WAN | 68/udp (sport 67) | **ALLOW** | DHCPv4 client — INPUT, not forward. Replies are often broadcasts and miss conntrack `related` |
| ISP DHCPv6 server | router WAN | 546/udp (sport 547) | **ALLOW** | DHCPv6-PD client; **only when IPv6 is enabled** |
| internet | janus WAN | 443/tcp, 80/tcp | **ALLOW** | **WAN INPUT to Caddy** (`enableWanCaddy`, Stage 7+). Not DNAT to TrueNAS |
| internet | router | WireGuard UDP **51820** | **ALLOW** | VPN |
| internet | any LAN | 22/tcp | **DENY** | No WAN SSH |
| trusted (20) | router | 22/tcp | **ALLOW** | Only VLAN that may SSH to router |
| mgmt / servers / iot / guest / vpn | router | 22/tcp | **DENY** | SSH locked to trusted (no VPN SSH in v1) |
| internet | any LAN | *other* | **DENY** | Default deny |
| internet (v6) | any | * | **DENY** | Default deny; open per-service if needed |

## LAN INPUT on janus (recommended)

Mgmt stays **infrastructure-only** for HTTPS. Admins browse lab UIs from
trusted, servers (jump/k8s), or VPN — not from VLAN 10.

| Source | Destination | Ports | Action | Notes |
|--------|-------------|-------|--------|-------|
| trusted + servers (+ wg0) | janus | 80, 443/tcp | **ALLOW** | Caddy lab vhosts. **Not mgmt, IoT, or guest** |
| WAN | janus | 80, 443/tcp | **ALLOW** Stage 7 | **WAN INPUT to Caddy** (`enableWanCaddy`) |
| trusted + servers + mgmt (+ wg0) | janus | 11443/tcp | **ALLOW** | UniFi UI. Mgmt included so you can use the AP’s native VLAN |
| mgmt (AP) + trusted + servers | `10.10.10.1` | 8080/tcp, 3478/udp, 10001/udp | **ALLOW** | UniFi Inform / STUN / discovery. **Do not put Headscale on :8080** |
| wg0 | janus | 53/udp+tcp | **ALLOW** Stage 6 | Split-horizon Unbound for VPN clients |
| localhost | Headscale | 8081/tcp | — | Caddy reverse_proxy only; no extra INPUT |

## East-west (VLAN 30)

| Source | Destination | Ports | Action | Notes |
|--------|-------------|-------|--------|-------|
| janus (Caddy) | `10.10.30.100` (Traefik LB) | 80/tcp | **ALLOW** | Caddy → k8s (OUTPUT) |
| janus (Caddy) | `10.10.30.20` | 3000, 8123, 9091/tcp | **ALLOW** | OUTPUT, not forward |
| iot, guest | `10.10.30.20` | all | **DENY** | |
| iot, guest | k8s nodes / API | all | **DENY** | |
| trusted + vpn | k8s API `10.10.30.11:6443` | 6443/tcp | **ALLOW** | kubectl from trusted |
| wan | Traefik LB, k8s nodes | all | **DENY** | No direct WAN → cluster |

## Home Assistant (canonical rules)

| Rule | Action |
|------|--------|
| HA (`10.10.30.20`) → IoT device IPs | **ALLOW** tcp/udp |
| IoT → HA UI `:8123` | **DENY** |
| Trusted + VPN → HA `:8123` | **DENY** — use `https://ha.lab.zdk.no` (Caddy + Authelia) |
| Trusted + VPN → janus `:443` | **ALLOW** |
| IoT → HA (new sessions) | **DENY**; return: established,related |

## Implementation notes

- Custom nftables (`networking.firewall.enable = false`) must include the **WAN DHCP client** INPUT exception; NixOS’s stock firewall is not in the path.
- **IoT DNS cutover:** `homelab.router.enableBlocky` (default off). Off → DHCP DNS is Unbound on `10.10.40.1`, INPUT `:53` from IoT is allowed, `domain-search lab.zdk.no` is pushed. On → DHCP DNS is Blocky; no IoT `domain-search`; prerouting **DNAT** `:53`/`:853` to `10.10.30.21` (port preserved, no SNAT so Blocky sees real client IPs — TrueNAS default gateway must be `10.10.30.1`); INPUT drop and WAN `:53`/`:853` drop (`oifname WAN`) are fallbacks. **IPv6:** same DNAT in `table ip6 nat` when `enableIpv6` is on **and** `blockyIpv6` is set to Blocky’s GUA (typically `<servers-/64>::21`). If v6 is on but `blockyIpv6` is null, IPv6 DNS to WAN is dropped so clients use IPv4 intercept. No IPv6 masquerade (native /64s). Deploy Blocky and confirm it answers **before** flipping `enableBlocky`. DoH on `:443` is not intercepted (would break HTTPS).
- Disable **UPnP/NAT-PMP** on router.
- **Hairpin NAT:** **Off.** Split-horizon DNS sends internal clients to `10.10.30.1` (Caddy on janus). Revisit only if a client resolves the public IP from inside the network.
- Export rule intent to `router/modules/firewall.nix`; validate in Stage 4.
