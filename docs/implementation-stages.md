# Implementation stages

Stages marked **(parallel)** can run concurrently. Architecture: [architecture.md](architecture.md).

## Stage 0 — Design and inventory (parallel with Stage 1)

- [x] Document devices — [inventory.md](inventory.md)
- [x] VLAN table and IP plan — [vlan-plan.md](vlan-plan.md)
- [x] Firewall matrix — [firewall-matrix.md](firewall-matrix.md)
- [ ] Document ISP IPv6 prefix size in [vlan-plan.md](vlan-plan.md)
- [x] CGNAT not active — dynamic public IPv4 confirmed
- [ ] Inventory NICs, switch, AP capabilities (802.1Q, SSID VLAN)

## Stage 1 — Hardware and physical (parallel with Stage 0)

- [ ] Verify OptiPlex 9020 MT: I217LM → WAN; i350-T2 port 1 → CRS310 trunk
- [ ] Cable modem (bridge) → WAN; trunk → CRS310; AP on trunk port
- [ ] Label ports per [inventory.md](inventory.md)

## Stage 2 — Core router (depends: Stage 1 WAN link)

- [ ] Install NixOS from flake; WAN DHCP/PPPoE
- [ ] VLAN interfaces; dnsmasq per [vlan-plan.md](vlan-plan.md)
- [ ] Default deny firewall; basic NAT; allow UniFi ports on LAN INPUT
- [ ] Unbound split-horizon; DNSUpdater timer
- [ ] IPv6 prefix delegation; native /64 per VLAN; document prefix in vlan-plan
- [ ] WireGuard + routes (incl. v6 to lab subnets when enabled)
- [ ] **UniFi OS Server** on OptiPlex (Podman + official installer); UI `:11443`; inform `:8080`
- [ ] Inform Host Override = router LAN IP reachable from AP (e.g. `10.10.10.1` or `10.10.30.1`)
- [ ] node_exporter for Prometheus scraping

## Stage 3 — Switch and WiFi VLANs (parallel: Stage 2 once router VLANs exist)

- [ ] CRS310: trunk to router, access ports per vlan-plan
- [ ] U7 Lite: adopt in UniFi OS Server on router; SSID → VLAN mapping; guest isolation
- [ ] Test wired + wireless clients land in correct subnet

## Stage 4 — Segmentation hardening (depends: Stage 3)

- [ ] Apply full [firewall-matrix.md](firewall-matrix.md)
- [ ] Deploy Blocky on TrueNAS; IoT DNS redirect
- [ ] mDNS: static IPs first; Avahi reflector servers↔IoT only if needed
- [ ] Validate: IoT cannot reach trusted; HA reaches IoT; IoT cannot reach HA UI

## Stage 5 — Internal services (parallel: Stage 4; needs servers VLAN)

**TrueNAS (internal only — no WAN exposure yet):**

- [ ] Static IP `10.10.30.20`
- [ ] Deploy `services/truenas/docker-compose.yml`: Caddy, **Home Assistant**, **Forgejo** (internal), **Authelia**, **Blocky**
- [ ] Caddy vhosts for `*.lab.zdk.no` with Authelia (VPN/trusted VLAN only)
- [ ] Forgejo: internal HTTPS via `code.lab.zdk.no` or direct; **LAN SSH enabled** (trusted + VPN)
- [ ] Promtail → Loki for TrueNAS container logs

**Kubernetes:**

- [ ] RK1: GiyoMoon NixOS mainline on NVMe; static IPs
- [ ] k3s cluster (nordri CP + sudri/austri/vestri workers); Flux bootstrap; **keep CP taint on nordri**; API at `10.10.30.11:6443`
- [ ] Longhorn: default StorageClass, replica 3, NVMe at `/var/lib/longhorn` on all RK1s
- [ ] MetalLB pool `10.10.30.100–110`; Traefik LB at `.100`
- [ ] kube-prometheus-stack (Prometheus, Grafana, Alertmanager, Loki)
- [ ] Capacitor at `capacitor.lab.zdk.no` via Caddy + Authelia
- [ ] Zdk ingress stub only — no app deploy until Zdk repo ships

**TLS (v1):** Internal `*.lab.zdk.no` — Caddy ACME via **split-horizon HTTP-01** (DNS-01 fallback). step-ca not in v1.

## Stage 6 — VPN and Headscale (depends: Stage 4; parallel with Stage 5)

- [ ] WireGuard clients (laptop, phone); test split-tunnel routes
- [ ] Deploy Headscale alongside WireGuard
- [ ] Confirm VPN → servers/mgmt; v6 routes to lab subnets

## Stage 7 — External access (public services)

VPN-first during Stages 0–6. Internal HA/Forgejo run in Stage 5; **WAN exposure** happens here.

**Forgejo (`code.zdk.no`) — can enable independently:**

- [ ] Domeneshop: `A`/`AAAA` for `code` only; DNSUpdater timer
- [ ] Caddyfile: `code.zdk.no` → Forgejo; ACME succeeds
- [ ] Confirm no WAN `:22`; LAN SSH still works on trusted/VPN
- [ ] External validation: `curl -I https://code.zdk.no`

**`zdk.no` — when Zdk repo ships deploy spec:**

- [ ] Domeneshop: `A`/`AAAA` for `@`; DNSUpdater
- [ ] Flux deploy from Zdk repo; Traefik IngressRoute
- [ ] External validation: `curl -I https://zdk.no`

**Always at Stage 7:**

- [ ] Confirm `*.lab.zdk.no` **not** WAN-reachable (no public DNS, no port forward)
- [ ] nftables rate-limit on WAN 443 (CrowdSec deferred — add only if logs warrant)
- [ ] SSL Labs scan on public hostnames

## Stage 8 — Operationalize (depends: all above)

- [ ] `validate.sh` in CI (flake check, caddy fmt)
- [ ] Runbooks: router restore, WG key rotation, ACME failure
- [ ] Security pass: disable unused services (UPS test only after UPS is procured — deferred)

## Ongoing — Repo scaffolding (parallel from day 0)

- [x] Scaffold `router/` NixOS flake (+ OPEN-QUESTIONS.md)
- [ ] Scaffold `nodes/`, finish `services/`, `secrets/`, `k8s/`

## Parallel workstreams

| Stream | Stages | Notes |
|--------|--------|-------|
| A — Physical | 0, 1 | Inventory + cabling |
| B — Router core | 2 | Blocks VLAN testing |
| C — L2 wireless | 3 | After router trunks |
| D — Policy | 4 | IoT isolation |
| E — Homelab | 5 | TrueNAS + k8s internal |
| F — Remote access | 6, 7 | VPN/Headscale then WAN |
| G — GitOps | 0→8 | Repo scaffolding |

**Max parallelism after Stage 2:** C, E, and F (WireGuard) in parallel; Stage 7 needs Caddy from E.

## Suggested first commits

1. `docs/vlan-plan.md` + `docs/firewall-matrix.md` *(done)*
2. `router/` NixOS flake skeleton *(started — see router/OPEN-QUESTIONS.md)*
3. `services/truenas/docker-compose.yml` + `services/caddy/Caddyfile`
4. `k8s/clusters/homelab/` Flux bootstrap + infrastructure HelmReleases
5. `secrets/.sops.yaml` + age key setup (documented, not committed)
6. `docs/runbooks/capacitor.md`
