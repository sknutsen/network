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
- [x] Label ports per [inventory.md](inventory.md)
- [x] Cable LAN first (trunk, AP, TrueNAS, Turing Pi, USW-NC/USW-LR/SW-O);
      **bridge OBOS Nett modem at cutover**, then modem → `wan0`

## Stage 2 — Core router (depends: Stage 1 WAN link)

- [x] Install NixOS with nixos-anywhere + disko (`.#optiplex`); WAN DHCP
- [x] VLAN interfaces; dnsmasq per [vlan-plan.md](vlan-plan.md)
- [x] Default deny firewall; basic NAT; allow UniFi ports on LAN INPUT
- [x] Unbound split-horizon; Caddy (`enableCaddy`; WAN closed until Stage 7)
- [x] IoT DHCP DNS = Unbound (`enableBlocky = false`); do not point IoT at
      Blocky yet
- [x] IPv6: OBOS Nett offers **no IPv6** (Stage 2 live + [OBOS](https://www.obos.no/boligselskap/nett/beboer/internett/fast-ip)).
      `enableIpv6` stays false; PD + `/64` per VLAN is in `networking.nix` for
      later. `blockyIpv6` remains null. Documented in [vlan-plan.md](vlan-plan.md)
- [x] **UniFi OS Server** on OptiPlex (functional): vendor binaries +
      `unifi.nix` systemd/rootless Podman; data `/var/lib/unifi-os-server`; UI
      `:11443`; inform `:8080` (Headscale must not use `:8080`)
- [x] Inform Host Override = **`10.10.10.1`** (AP and Flex Minis native VLAN
      10). Do not use `10.10.30.1` — that is Caddy, not Inform.
- [x] node_exporter for Prometheus scraping

## Stage 3 — Switch and WiFi VLANs (parallel: Stage 2 once router VLANs exist)

- [x] CRS310: import [switch/crs310.rsc](../switch/crs310.rsc) (L2 VLAN filter;
      mgmt `10.10.10.2`; ether6 trunk to USW-NC)
- [x] U7 Lite: adopt in UniFi OS Server on router; SSIDs `Hai-Fi Wai-Fi` /
      `(IoT)` / `(Guest)` → VLANs 20/40/50; guest isolation; Inform Host
      `10.10.10.1`
- [x] USW-NC / USW-LR: adopt; mgmt `10.10.10.3` / `10.10.10.4` on VLAN 10; port
      profiles per [vlan-plan.md](vlan-plan.md)
- [x] Test wired + wireless clients land in correct subnet

## Stage 4 — Segmentation hardening (depends: Stage 3)

Blocky **deploy** was Stage 5 compose. `enableBlocky` is **true** (IoT DHCP +
DNAT to `.21`).

- [x] Apply [firewall-matrix.md](firewall-matrix.md) except IoT DNS cutover
      (cutover is Stage 5; `enableBlocky` is now true)
- [x] mDNS: static IPs first; Avahi reflector servers↔IoT (Matter / Dirigera)
- [x] Trusted→IoT cast allows (TV/Chromecast/Odyssey) here or with HA — not at
      Stage 3. Uncomment the nftables cast rule when enabling.

## Stage 5 — Internal services (parallel: Stage 4; needs servers VLAN)

**TrueNAS (internal only — no WAN exposure yet):**

- [x] Static IP `10.10.30.20` (dnsmasq reservation `cc:28:aa:42:c2:9d`)
- [x] **Home Assistant** — TrueNAS App on `10.10.30.20:30103` (`ha.lab.zdk.no`)
- [x] **Immich** — TrueNAS App on `10.10.30.20:30041` (`immich.lab.zdk.no`)
- [x] **Authelia** — TrueNAS App on `10.10.30.20:9091`; portal
      `https://auth.lab.zdk.no` ([README](../services/authelia/README.md)). Do
      not also start compose Authelia on `:9091`.
- [x] **Forgejo** — TrueNAS App on `10.10.30.20:30142` (UI) / `:30143`
      (SSH); `code.lab.zdk.no`, no Authelia. Do not also start compose
      Forgejo on those ports.
- [x] **Blocky** — TrueNAS Custom App on `10.10.30.21:53` (alias on `eno1`)
- [x] Confirm Blocky answers on `.21`; `enableBlocky = true` (DHCP, DNAT, no
      IoT domain-search). `blockyIpv6` stays null until ISP IPv6.
- [x] Validate IoT DNS (2026-09-12): DHCP DNS is `.21` (`dhcp-option-force`;
      scoped `domain=` so IoT gets no option 15 / search). Intercept
      `@8.8.8.8` answers; `@10.10.40.1 grafana.lab.zdk.no` is NXDOMAIN
      (Blocky, not Unbound). Lease **1 h**. Procedure:
      [runbooks/iot-dns.md](runbooks/iot-dns.md).
- [x] Caddy on janus: Authelia on lab UIs except `auth` / `code.lab` / `ha.lab`
      / `immich.lab` / `truenas.lab` / `unifi.lab` / (later) `headscale.lab`. UI
      is `https://truenas.lab.zdk.no` (not the raw IP — TrueNAS host firewall is
      same-subnet only).
- [x] DNS-01: Domeneshop plugin on Caddy (`withPlugins`) + sops
      `caddy.domeneshopToken`/`Secret`; `caddyEmail`; lab certs issue. Caddyfile
      `dns01` snippet uses public resolvers (`1.1.1.1` / `9.9.9.9`) and
      `propagation_delay 60s` — janus Unbound has no NS for `zdk.no`, so
      certmagic must not use `127.0.0.53`. No public A records for lab names.
- [x] Forgejo: internal HTTPS via `code.lab.zdk.no`; **LAN SSH on `:30143`**
      (trusted + VPN)
- [x] Promtail on TrueNAS (`docker compose --profile logging up -d promtail`)
      → Loki `10.10.30.101:3100`. Drops samples older than 24h (Mailcow
      history). Push URL is not behind Authelia.

**Kubernetes:**

- [x] RK1: GiyoMoon NixOS mainline on NVMe; `nodes/` flake; static `.11`–`.14` + ULA (`end0`)
- [x] k3s cluster (nordri CP + sudri/austri/vestri workers); Flux bootstrap
      (`--token-auth`); **CP taint kept on nordri**; API at
      `10.10.30.11:6443`. No kube-vip; `.10` reserved.
- [x] Longhorn: default StorageClass, replica 3, NVMe at `/var/lib/longhorn` on
      all RK1s
- [x] MetalLB pool `10.10.30.100–110`; Traefik LB at `.100`
- [x] kube-prometheus-stack (Prometheus, Grafana, Alertmanager) + Loki sibling
      HelmRelease. Grafana login is Authelia (`Remote-User`); no Grafana form.
- [x] Capacitor at `capacitor.lab.zdk.no` via Caddy + Authelia (`allow-capacitor`
      netpol for Traefik)
- [x] Zdk ingress stub only — GitRepository **suspended**; no app deploy until
      Zdk repo ships

**TLS (v1):** Caddy ACME **DNS-01 (Domeneshop)** for lab **and** public names.
Custom Caddy with `github.com/caddy-dns/domainnameshop` + sops API credentials.
`dns01` snippet: public resolvers + 60s propagation delay. Unbound still points
lab names at `10.10.30.1` for browsing. `enableWanCaddy` is only for _serving_
WAN 80/443, not issuance. step-ca not in v1.

## Stage 6 — VPN and Headscale (depends: Stage 4; parallel with Stage 5)

- [x] WireGuard on janus (`51820/udp`); Pixel (`10.10.255.2`) from LTE —
      Grafana/Authelia, split-tunnel (WAN stays LTE), SSH to janus denied
      (2026-09-12). Remorse (`10.10.255.3`) profile is on janus; turn the
      Mac tunnel on off-lab to confirm handshake.
- [ ] Remorse away handshake (`10.10.255.3`)
- [x] Headscale on janus `127.0.0.1:8081`; Caddy `headscale.lab.zdk.no`
      (no Authelia). User `zdk`; Remorse `100.64.0.1` + Pixel `100.64.0.2`
      online (2026-09-12).
- [ ] Confirm VPN → servers/mgmt/Caddy; v6 routes to lab subnets

## Stage 7 — External access (public services)

VPN-first during Stages 0–6. Internal HA/Immich/Forgejo run in Stage 5; **WAN
exposure** happens here.

**Immich (`img.zdk.no`) and Home Assistant (`ha.zdk.no`):**

- [x] Domeneshop: `A` for `img` and `ha` → `84.48.97.100` (no AAAA)
- [x] `enableWanCaddy = true`; WAN 80/443 to Caddy; `wan_https4` meter
      (2026-09-12)
- [x] HA `configuration.yaml`: `external_url` / `internal_url` /
      `trusted_proxies` (2026-09-12)
- [x] Immich admin: external domain `https://img.zdk.no` (2026-09-12)
- [x] External validation: Pixel LTE, WG off — `https://img.zdk.no` and
      `https://ha.zdk.no` resolve (2026-09-12)
- [x] Public DNS: `immich.lab` / `ha.lab` NXDOMAIN. `lab_only` still on
      the vhosts.
- [x] DNSUpdater flake module on janus: Domeneshop `img` + `ha` + `vpn`
      via sops `dnsupdater.domeneshopToken`/`Secret`; Loki
      `10.10.30.101:3100` (`enableDnsUpdater = true`)

**Forgejo (`code.zdk.no`) — can enable independently:**

- [ ] Domeneshop: `A`/`AAAA` for `code`; add `code` to DNSUpdater records
- [ ] Caddyfile: uncomment `code.zdk.no`; set Forgejo `ROOT_URL` to
      `https://code.zdk.no`
- [ ] Confirm no WAN `:22`; LAN SSH still works on trusted/VPN
- [ ] External validation: `curl -I https://code.zdk.no`

**`zdk.no` — when Zdk repo ships deploy spec:**

- [ ] Domeneshop: `A`/`AAAA` for `@`; add `@` to DNSUpdater records
- [ ] Flux deploy from Zdk repo; Traefik IngressRoute
- [ ] External validation: `curl -I https://zdk.no`

**Always at Stage 7:**

- [x] `*.lab.zdk.no` has no public `A`/`AAAA` (NXDOMAIN). WAN INPUT is
      Caddy 80/443 only; SSH still trusted-only.
- [x] nftables `wan_https4` on WAN 80/443 (25/s per source). CrowdSec
      deferred.
- [x] SSL Labs: `img.zdk.no` and `ha.zdk.no` both **A** (2026-09-12). TLS 1.2/1.3, no HSTS (A+ would need it).

## Stage 8 — Operationalize (depends: all above)

- [ ] Network dashboard live: rebuild janus (presence `:9101`); Flux apply
      scrape jobs + Grafana **Network**; publish Blocky `:4000` on `.21`
- [ ] `validate.sh` in CI (flake check, caddy fmt)
- [x] Runbooks: router restore, WG key rotation, ACME failure, Capacitor,
      IoT DNS — [runbooks/](runbooks/)
- [ ] Security pass: disable unused services (UPS test only after UPS is
      procured — deferred)

## Ongoing — Repo scaffolding (parallel from day 0)

- [x] Scaffold `router/` NixOS flake (+ OPEN-QUESTIONS.md)
- [x] Scaffold `nodes/` RK1 NixOS flake (k3s now on)
- [x] Scaffold `k8s/` Flux tree (bootstrap + infra HelmReleases)
- [x] Encrypted `secrets/router.yaml` + `secrets/.sops.yaml` (janus / pingu /
      remorse age recipients). Caddy Domeneshop env via sops-nix template.
- [x] Encrypted cluster secrets: `nodes/secrets/cluster.yaml` (k3s token,
      sops-nix on RK1s) and `k8s/.../grafana-admin.secret.yaml` (Flux sops).
      Not `secrets/cluster.yaml` (nodes flake cannot import `../secrets`).
- [x] `docs/runbooks/` — restore, WG rotation (Stage 6 stub), ACME,
      Capacitor, IoT DNS

## Parallel workstreams

| Stream            | Stages | Notes                                                                                   |
| ----------------- | ------ | --------------------------------------------------------------------------------------- |
| A — Physical      | 0, 1   | Inventory + cabling                                                                     |
| B — Router core   | 2      | Blocks VLAN testing                                                                     |
| C — L2 wireless   | 3      | After router trunks                                                                     |
| D — Policy        | 4      | Firewall except IoT DNS cutover                                                         |
| E — Homelab       | 5      | TrueNAS Apps (HA/Immich/Authelia/Forgejo) + Custom App (Blocky) + k8s; `enableBlocky` on |
| F — Remote access | 6, 7   | WireGuard/Headscale then WAN INPUT to Caddy                                             |
| G — GitOps        | 0→8    | Repo scaffolding                                                                        |

**Max parallelism after Stage 2:** C and E in parallel with D (except
`enableBlocky`, which waits on Blocky from E). F (WireGuard) after Stage 4.
Stage 7 needs Caddy on janus (Stage 2) plus TrueNAS backends from E.

## Suggested next commits

Already in tree through Stage 5 (k3s, Flux, Loki, Promtail, cluster sops).

Still to add:

1. Stage 6 WireGuard / Headscale keys in `secrets/router.yaml`
