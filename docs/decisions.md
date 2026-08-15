# Decisions

Canonical decision log for the homelab network. Rationale lives in the **Why**
column; alternatives in `docs/reference/`.

## Principles

- **Self-hosted first** — no Cloudflare, Tailscale SaaS, or tunnel vendors
  unless unavoidable.
- **Declarative config** — NixOS flakes, Git, SOPS, Flux, Compose files in this
  repo.
- **VPN-first** — WireGuard + Headscale for admin; minimum public exposure.
- **Router as policy point** — nftables on NixOS; everything else runs on VLAN
  hosts.

## Decision table

| Layer             | Choice                                                         | Why                                                             |
| ----------------- | -------------------------------------------------------------- | --------------------------------------------------------------- |
| Router OS         | **NixOS** (flakes + nftables)                                  | Declarative, rollbacks, unified with RK1 nodes                  |
| Router hardware   | **Dell OptiPlex 9020 MT** + **Intel i350-T2** (acquired)       | I217LM = WAN, i350 = LAN trunk — not router-on-a-stick          |
| Switch            | **MikroTik CRS310-8G+2S+IN** (acquired)                        | 802.1Q VLANs, 2.5G ports, SNMP                                  |
| WiFi AP           | **Ubiquiti U7 Lite** (1×, acquired)                            | WiFi 7; 2.5 GbE uplink; VLAN-capable SSIDs; ~115 m² coverage    |
| UPS               | **Deferred** — not required for v1                             | Procure later; optional Stage 8 power test                      |
| UniFi             | **UniFi OS Server on OptiPlex (router)**                       | Official self-host via Podman; UI `:11443`, inform `:8080`; frees TrueNAS ports; NixOS runs vendor installer (impure) alongside flake |
| DHCP              | **dnsmasq** on router                                          | Simple per-VLAN pools; NixOS-native                             |
| DNS (internal)    | **Unbound** on router                                          | Split-horizon, recursive resolver                               |
| DNS (IoT filter)  | **Blocky** on TrueNAS Docker                                   | Git-friendly blocklists; IoT-only policy                        |
| Edge proxy        | **Caddy** on TrueNAS Docker                                    | ACME, Caddyfile in Git, forward-auth                            |
| K8s ingress       | **Traefik** in-cluster                                         | Dynamic pod routing, IngressRoute CRDs                          |
| K8s GitOps        | **Flux + Capacitor**                                           | Git-native deploys; self-hosted UI behind Authelia              |
| K8s cluster       | **4× RK1** on Turing Pi 2.5, **k3s**                           | ARM64 homelab; expandable with x86 workers                      |
| K8s control plane | **`nordri` sole CP** at `10.10.30.11:6443`; **CP taint kept**; `.10` reserved | Workloads on `sudri`–`vestri`; no kube-vip until second CP |
| RK1 node OS       | **NixOS** (GiyoMoon mainline)                                  | Unified ops with router; escape hatches documented only         |
| Storage (K8s)     | **Longhorn** — default StorageClass, **replica 3**, NVMe at `/var/lib/longhorn` per RK1 | 4 nodes × 256 GB+; ~256 GB usable replicated capacity; Velero/ZFS backup off-cluster |
| Auth / SSO        | **Authelia** on TrueNAS Docker                                 | Caddy `forward_auth`; YAML in Git                               |
| Secrets           | **sops-nix + age**                                             | One SOPS workflow for router, Flux, services                    |
| VPN               | **WireGuard** on router + **Headscale**                        | Fast kernel WG; mesh overlay alongside VPN                      |
| WAN IDS           | **Not in v1** (CrowdSec deferred)                              | nftables rate-limit on 443 first; add CrowdSec if logs warrant  |
| DDNS              | **DNSUpdater** → **Domeneshop**                                | Dynamic `A`/`AAAA` for `@` and `code` only                      |
| Monitoring        | **kube-prometheus-stack** in k8s                               | Prometheus, Grafana, Alertmanager, Loki in one Helm release     |
| Logging (edge)    | **Promtail** on TrueNAS → Loki in k8s                          | Caddy/HA/Forgejo Docker logs to Loki; UniFi logs on router      |
| Public services   | **`zdk.no`** + **`code.zdk.no`**                               | Zdk on k8s; Forgejo on TrueNAS; Stage 7 WAN                     |
| `zdk.no` app      | **[github.com/sknutsen/Zdk](https://github.com/sknutsen/Zdk)** | App code external                                               |
| Zdk GitOps        | **Flux `GitRepository` + `Kustomization` → Zdk repo**          | Zdk repo owns Deployment/Service/image; `net/` ingress stub + Flux CR |
| Forgejo Git (WAN) | **HTTPS only**                                                 | No WAN `:22`; LAN SSH enabled on trusted VLAN + VPN             |
| Internal admin    | **`*.lab.zdk.no`**                                             | Split-horizon only; VPN/trusted VLAN; Authelia; never WAN       |
| WAN IPv4          | **Dynamic public IP** (CGNAT not active)                       | Port forward 443/80 + WireGuard UDP                             |
| WAN IPv6          | **Prefix delegation**; **native /64 per VLAN**                 | WAN inbound v6 default deny; NPTv6 only if ISP delegates `/60` or smaller |
| ISP modem         | **Bridge mode**                                                | OptiPlex is sole router                                         |
| Home Assistant    | **Docker on TrueNAS**, VLAN 30                                 | HA initiates to IoT; stays off IoT VLAN                         |
| TrueNAS compose   | **Single** `services/truenas/docker-compose.yml`               | Caddy, HA, Forgejo, Authelia, Blocky (no UniFi)                 |
| Location          | **Norway**, ~60 m² flat                                        | 1 AP; EU/NO retailers where possible                            |

## Exposure matrix

| Hostname           | WAN           | Authelia | Notes                                  |
| ------------------ | ------------- | -------- | -------------------------------------- |
| `zdk.no`           | Yes (Stage 7) | No       | Public app                             |
| `code.zdk.no`      | Yes (Stage 7) | No       | Forgejo; HTTPS git on WAN              |
| `*.lab.zdk.no`     | **No**        | Yes      | Admin UIs; split-horizon internal only |
| Future public apps | Per-app       | Optional | Can add Authelia in front if needed    |

## TLS (v1)

| Layer                                | Approach                                                                              |
| ------------------------------------ | ------------------------------------------------------------------------------------- |
| Public WAN (`zdk.no`, `code.zdk.no`) | Caddy ACME (Let's Encrypt)                                                            |
| Internal (`*.lab.zdk.no`)            | **Caddy ACME via split-horizon HTTP-01**; DNS-01 (Domeneshop) fallback only | Unbound → `10.10.30.20`; no public DNS for `lab` names |
| Caddy → Traefik (east-west)          | HTTP on VLAN 30 — mTLS is a non-goal for v1                                           |
| step-ca                              | **Not in v1** — Caddy ACME covers edge; revisit for mTLS/device certs if needed      |

## Alternatives (reference only)

| Topic         | Chosen                  | Reference                                                                  |
| ------------- | ----------------------- | -------------------------------------------------------------------------- |
| Auth          | Authelia                | [auth-authelia-vs-authentik.md](reference/auth-authelia-vs-authentik.md)   |
| Secrets       | sops-nix                | [secrets-sops-vs-agenix.md](reference/secrets-sops-vs-agenix.md)           |
| GitOps        | Flux + Capacitor        | [gitops-flux-vs-argocd.md](reference/gitops-flux-vs-argocd.md)             |
| Router OS     | NixOS                   | [router-os-alternatives.md](reference/router-os-alternatives.md)           |
| RK1 OS escape | NixOS default           | [escape-hatches-ubuntu-talos.md](reference/escape-hatches-ubuntu-talos.md) |
| CGNAT         | Not active              | [cgnat-options.md](reference/cgnat-options.md)                             |
| RK1 BSP / NPU | Deferred                | [plans/rk1-bsp-fork.md](plans/rk1-bsp-fork.md)                             |
| Hardware BOM  | Core gear acquired; UPS deferred | [hardware-bom-norway.md](reference/hardware-bom-norway.md)          |
