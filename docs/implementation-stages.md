# Implementation stages

Stages marked **(parallel)** can run concurrently. Architecture:
[architecture.md](architecture.md).

## Stage 0 — Design and inventory (parallel with Stage 1)

- [x] Document devices — [inventory.md](inventory.md)
- [x] VLAN table and IP plan — [vlan-plan.md](vlan-plan.md)
- [x] Firewall matrix — [firewall-matrix.md](firewall-matrix.md)
- [x] ISP named (**OBOS Nett**); IPv6 prefix size is captured at Stage 2
- [x] CGNAT not active — dynamic public IPv4 confirmed
- [x] Inventory NICs, switch, AP capabilities (802.1Q, SSID VLAN) — physical
      verify is Stage 1

## Stage 1 — Hardware and physical (parallel with Stage 0)

- [x] Verify OptiPlex 9020 MT: I217LM → WAN; i350-T2 port 1 → CRS310 trunk
      (`ethtool -p lan0`)
- [ ] Label ports per [inventory.md](inventory.md)
- [ ] Cable LAN first (trunk, AP, TrueNAS, Turing Pi, USW-NC/USW-LR/SW-O); **bridge OBOS Nett modem
      at cutover**, then modem → `wan0`

## Stage 2 — Core router (depends: Stage 1 WAN link)

- [x] Install NixOS with nixos-anywhere + disko (`.#optiplex`); WAN DHCP
- [ ] VLAN interfaces; dnsmasq per [vlan-plan.md](vlan-plan.md)
- [ ] Default deny firewall; basic NAT; allow UniFi ports on LAN INPUT
- [ ] Unbound split-horizon; Caddy (`enableCaddy`; WAN closed until Stage 7)
- [ ] IoT DHCP DNS = Unbound (`enableBlocky = false`); do not point IoT at
      Blocky yet
- [ ] IPv6: set `enableIpv6 = true`; native /64 per VLAN; document OBOS Nett
      prefix **and Blocky GUA** in vlan-plan; leave `blockyIpv6` null until GUA
      known
- [x] **UniFi OS Server** on OptiPlex (functional): vendor binaries +
      `unifi.nix` systemd/rootless Podman; data `/var/lib/unifi-os-server`; UI
      `:11443`; inform `:8080` (Headscale must not use `:8080`)
- [x] Inform Host Override = **`10.10.10.1`** (AP and Flex Minis native VLAN 10). Do not use
      `10.10.30.1` — that is Caddy, not Inform.
- [ ] node_exporter for Prometheus scraping

## Stage 3 — Switch and WiFi VLANs (parallel: Stage 2 once router VLANs exist)

- [x] CRS310: import [switch/crs310.rsc](../switch/crs310.rsc) (L2 VLAN filter;
      mgmt `10.10.10.2`; ether6 trunk to USW-NC)
- [ ] U7 Lite: adopt in UniFi OS Server on router; SSIDs `Hai-Fi Wai-Fi` /
  `(IoT)` / `(Guest)` → VLANs 20/40/50; guest isolation; Inform Host
  `10.10.10.1`
- [ ] USW-NC / USW-LR: adopt; mgmt `10.10.10.3` / `10.10.10.4` on VLAN 10;
      port profiles per [vlan-plan.md](vlan-plan.md)
- [ ] Test wired + wireless clients land in correct subnet

## Stage 4 — Segmentation hardening (depends: Stage 3)

Blocky **deploy** is Stage 5 compose. Do not flip `enableBlocky` until Stage 5
confirms `.21` answers.

- [ ] Apply [firewall-matrix.md](firewall-matrix.md) except IoT DNS cutover
      (`enableBlocky` stays false)
- [ ] mDNS: static IPs first; Avahi reflector servers↔IoT only if needed
- [ ] Trusted→IoT cast allows (TV/Chromecast/Odyssey) here or with HA — not at
      Stage 3. Uncomment the nftables cast rule when enabling.

## Stage 5 — Internal services (parallel: Stage 4; needs servers VLAN)

**TrueNAS (internal only — no WAN exposure yet):**

- [ ] Static IP `10.10.30.20`
- [ ] Deploy `services/truenas/docker-compose.yml`: **Home Assistant**,
      **Forgejo** (internal `code.lab.zdk.no`, no Authelia), **Authelia**,
      **Blocky** (`10.10.30.21` alias on TrueNAS)
- [ ] Confirm Blocky answers on `.21`; then set
      `homelab.router.enableBlocky = true` and rebuild (DHCP, DNAT, no IoT
      domain-search). If IPv6 is on, set `blockyIpv6` too.
- [ ] Validate IoT DNS: DHCP DNS is `.21`; `dig @8.8.8.8 example.com` from IoT
      still resolves (intercept); IoT cannot use Unbound on `10.10.40.1` as a
      bypass. IoT lease is **1 h**.
- [ ] Caddy on janus: Authelia on lab UIs except `auth` / `code.lab` / (later)
      `headscale.lab`. Public `zdk.no` / `code.zdk.no` stay commented;
      `enableWanCaddy` stays false until Stage 7.
- [ ] DNS-01: Domeneshop plugin on Caddy + sops
      `caddy.domeneshopToken`/`Secret`; set `caddyEmail`; first lab certs issue
      (no public A records)
- [ ] Forgejo: internal HTTPS via `code.lab.zdk.no` or direct; **LAN SSH
      enabled** (trusted + VPN)
- [ ] Promtail stub in compose (`--profile logging`) → Loki; enable after Loki
      is up; push URL must not go through Authelia

**Kubernetes:**

- [ ] RK1: GiyoMoon NixOS mainline on NVMe; static IPs
- [ ] k3s cluster (nordri CP + sudri/austri/vestri workers); Flux bootstrap;
      **keep CP taint on nordri**; API at `10.10.30.11:6443`
- [ ] Longhorn: default StorageClass, replica 3, NVMe at `/var/lib/longhorn` on
      all RK1s
- [ ] MetalLB pool `10.10.30.100–110`; Traefik LB at `.100`
- [ ] kube-prometheus-stack (Prometheus, Grafana, Alertmanager, Loki)
- [ ] Capacitor at `capacitor.lab.zdk.no` via Caddy + Authelia
- [ ] Zdk ingress stub only — no app deploy until Zdk repo ships

**TLS (v1):** Internal `*.lab.zdk.no` — Caddy ACME **DNS-01 (Domeneshop)**.
Custom Caddy with `github.com/caddy-dns/domainnameshop` + sops API credentials.
Unbound still points lab names at `10.10.30.1` for browsing. step-ca not in v1.

## Stage 6 — VPN and Headscale (depends: Stage 4; parallel with Stage 5)

- [ ] WireGuard on janus (`51820/udp`); clients (laptop, phone); test
      split-tunnel routes
- [ ] Deploy **Headscale on janus** listening on **`127.0.0.1:8081`** (not
      `:8080` — UniFi Inform). Caddy `headscale.lab.zdk.no`, no Authelia.
- [ ] Confirm VPN → servers/mgmt/Caddy; v6 routes to lab subnets

## Stage 7 — External access (public services)

VPN-first during Stages 0–6. Internal HA/Forgejo run in Stage 5; **WAN
exposure** happens here.

**Forgejo (`code.zdk.no`) — can enable independently:**

- [ ] Domeneshop: `A`/`AAAA` for `code` only; DNSUpdater timer
- [ ] Caddyfile: uncomment `code.zdk.no`; set Forgejo `ROOT_URL` to
      `https://code.zdk.no`; set `enableWanCaddy = true` + `caddyEmail`; DNS-01
      ACME succeeds (WAN 80 not required for issuance)
- [ ] Confirm no WAN `:22`; LAN SSH still works on trusted/VPN
- [ ] External validation: `curl -I https://code.zdk.no`

**`zdk.no` — when Zdk repo ships deploy spec:**

- [ ] Domeneshop: `A`/`AAAA` for `@`; DNSUpdater
- [ ] Flux deploy from Zdk repo; Traefik IngressRoute
- [ ] External validation: `curl -I https://zdk.no`

**Always at Stage 7:**

- [ ] Confirm `*.lab.zdk.no` **not** WAN-reachable (no public DNS, no WAN INPUT
      except Caddy 80/443 for public names)
- [ ] nftables rate-limit on WAN 443 (CrowdSec deferred — add only if logs
      warrant)
- [ ] SSL Labs scan on public hostnames

## Stage 8 — Operationalize (depends: all above)

- [ ] `validate.sh` in CI (flake check, caddy fmt)
- [ ] Runbooks: router restore, WG key rotation, ACME failure
- [ ] Security pass: disable unused services (UPS test only after UPS is
      procured — deferred)

## Ongoing — Repo scaffolding (parallel from day 0)

- [x] Scaffold `router/` NixOS flake (+ OPEN-QUESTIONS.md)
- [x] Scaffold `nodes/` RK1 NixOS flake (k3s off until Stage 5)
- [x] Scaffold `k8s/` Flux tree (bootstrap + infra HelmReleases)
- [ ] Encrypted `secrets/*.yaml` and `docs/runbooks/`

## Parallel workstreams

| Stream            | Stages | Notes                                                     |
| ----------------- | ------ | --------------------------------------------------------- |
| A — Physical      | 0, 1   | Inventory + cabling                                       |
| B — Router core   | 2      | Blocks VLAN testing                                       |
| C — L2 wireless   | 3      | After router trunks                                       |
| D — Policy        | 4      | Firewall except IoT DNS cutover                           |
| E — Homelab       | 5      | TrueNAS compose (incl. Blocky) + k8s; then `enableBlocky` |
| F — Remote access | 6, 7   | WireGuard/Headscale then WAN INPUT to Caddy               |
| G — GitOps        | 0→8    | Repo scaffolding                                          |

**Max parallelism after Stage 2:** C and E in parallel with D (except
`enableBlocky`, which waits on Blocky from E). F (WireGuard) after Stage 4.
Stage 7 needs Caddy on janus (Stage 2) plus TrueNAS backends from E.

## Suggested next commits

Already in tree: vlan/firewall/inventory docs, router flake, `nodes/` RK1
flake, `k8s/` Flux tree, CRS310 `.rsc`, TrueNAS compose, Caddyfile,
Authelia/Blocky/Promtail stubs, Zdk IngressRoute stub.

Still to add:

1. Encrypted `secrets/router.yaml` (age key on janus — do not commit the key)
2. `docs/runbooks/` (router restore, WG rotation, ACME, Capacitor)
