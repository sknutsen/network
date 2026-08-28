# Decisions

Canonical decision log for the homelab network. Rationale lives in the **Why**
column; alternatives in `docs/reference/`. Options and history:
`docs/decision-briefs.md` (stable brief IDs). Remaining unanswered items:
`docs/plan.md` § Remaining decisions and `router/OPEN-QUESTIONS.md`.

**For agents:** When the user answers a question, (1) add or update the row
here, (2) set the matching brief to **Resolved** (keep options as history),
(3) delete it from `plan.md` § Remaining decisions. Do not keep resolved rows
on the remaining list. Do not invent a second numbering scheme — brief IDs
are canonical.

## Principles

- **Self-hosted first** — no Cloudflare, Tailscale SaaS, or tunnel vendors
  unless unavoidable.
- **Declarative config** — NixOS flakes, Git, SOPS, Flux, Compose files in this
  repo.
- **VPN-first** — WireGuard + Headscale for admin; minimum public exposure.
- **Router as policy point** — nftables on NixOS. The same host also runs
  **edge services that must stay up with the gateway:** Unbound, dnsmasq,
  Caddy, UniFi OS Server, Headscale, DNSUpdater. Apps and filters that do not
  need the edge (HA, Forgejo, Authelia, Blocky, k8s) stay on VLAN hosts.

## Decision table

| Layer             | Choice                                                         | Why                                                             |
| ----------------- | -------------------------------------------------------------- | --------------------------------------------------------------- |
| Router OS         | **NixOS** (flakes + nftables)                                  | Declarative, rollbacks, unified with RK1 nodes                  |
| Router hardware   | **Dell OptiPlex 9020 MT** + **Intel i350-T2** (acquired)       | I217LM = WAN, i350 = LAN trunk — not router-on-a-stick          |
| Router install    | **nixos-anywhere** + **disko**                                 | SSH from a workstation; declarative disk; Mac uses `--build-on remote` |
| Switch            | **MikroTik CRS310-8G+2S+IN** (acquired)                        | 802.1Q VLANs, 2.5G ports, SNMP                                  |
| WiFi AP           | **Ubiquiti U7 Lite** (1×, acquired)                            | WiFi 7; 2.5 GbE uplink; VLAN-capable SSIDs; ~115 m² coverage    |
| UPS               | **Deferred** — not required for v1                             | Procure later; optional Stage 8 power test                      |
| UniFi             | **UniFi OS Server on OptiPlex only**; data `/var/lib/unifi-os-server` | Official self-host via Podman; UI `:11443`, inform `:8080` at `10.10.10.1`; `unifi.lab.zdk.no` → Caddy `.30.1`; **not** on TrueNAS |
| DHCP              | **dnsmasq** on router                                          | Simple per-VLAN pools; NixOS-native                             |
| DNS (internal)    | **Unbound** on router                                          | Split-horizon, recursive resolver                               |
| DNS (IoT filter)  | **Blocky** on TrueNAS Docker at `10.10.30.21`                  | Git-friendly blocklists; IoT-only; not k8s or router            |
| Edge proxy        | **Caddy** on janus (NixOS)                                     | ACME, Caddyfile in Git, forward-auth; frees TrueNAS 80/443      |
| K8s ingress       | **Traefik** in-cluster                                         | Dynamic pod routing, IngressRoute CRDs                          |
| K8s GitOps        | **Flux + Capacitor**                                           | Git-native deploys; self-hosted UI behind Authelia              |
| K8s cluster       | **4× RK1** on Turing Pi 2.5, **k3s**                           | ARM64 homelab; expandable with x86 workers                      |
| K8s control plane | **`nordri` sole CP** at `10.10.30.11:6443`; **CP taint kept**; `.10` reserved | Workloads on `sudri`–`vestri`; no kube-vip until second CP |
| RK1 node OS       | **NixOS** (GiyoMoon mainline)                                  | Unified ops with router; escape hatches documented only         |
| Storage (K8s)     | **Longhorn** — default StorageClass, **replica 3**, NVMe at `/var/lib/longhorn` per RK1 | 4 nodes × 256 GB+; ~256 GB usable replicated capacity; Velero/ZFS backup off-cluster |
| Auth / SSO        | **Authelia** on TrueNAS Docker                                 | Caddy `forward_auth` for lab UIs; exceptions below              |
| Secrets           | **sops-nix + age**; key `/var/lib/sops-nix/key.txt` on janus   | One SOPS workflow; workstation age identity in `.sops.yaml`     |
| VPN               | **WireGuard** (`51820`) + **Headscale** on janus               | Headscale **`127.0.0.1:8081`** behind Caddy (`headscale.lab.zdk.no`); **not** `:8080` (UniFi Inform) |
| WAN IDS           | **Not in v1** (CrowdSec deferred)                              | nftables rate-limit on 443 first; add CrowdSec if logs warrant  |
| DDNS              | **DNSUpdater** → **Domeneshop** (package in DNSUpdater repo)   | Dynamic `A`/`AAAA` for `@` and `code` only; this flake waits    |
| Monitoring        | **kube-prometheus-stack** in k8s                               | Prometheus, Grafana, Alertmanager, Loki in one Helm release     |
| Logging (edge)    | **Promtail** on TrueNAS → Loki; Caddy logs on janus            | HA/Forgejo/Authelia Docker logs to Loki; Caddy via journald     |
| Public services   | **`zdk.no`** + **`code.zdk.no`**                               | Zdk on k8s; Forgejo on TrueNAS; Stage 7 WAN                     |
| `zdk.no` app      | **[github.com/sknutsen/Zdk](https://github.com/sknutsen/Zdk)** | App code external                                               |
| Zdk GitOps        | **Flux `GitRepository` + `Kustomization` → Zdk repo**          | Zdk repo owns Deployment/Service/image; `net/` `ingressroute.yaml` stub + Flux CR |
| Forgejo Git (WAN) | **HTTPS only**                                                 | No WAN `:22`; LAN SSH enabled on trusted VLAN + VPN             |
| Internal admin    | **`*.lab.zdk.no`**                                             | Split-horizon only; VPN/trusted VLAN; Authelia; never WAN       |
| WAN IPv4          | **Dynamic public IP** (CGNAT not active)                       | **WAN INPUT to Caddy** 443/80 on janus (Stage 7) + WireGuard UDP |
| WAN IPv6          | **Prefix delegation at Stage 2**; **native /64 per VLAN**      | Enable `enableIpv6` with WAN; inbound v6 default deny; NPTv6 only if ISP delegates `/60` or smaller |
| ISP               | **OBOS Nett**                                                  | Dynamic public IPv4; DHCPv6-PD size TBD at Stage 2              |
| ISP modem         | **Bridge mode** — configure at router cutover                  | OptiPlex is sole router                                         |
| Hairpin NAT       | **Off**                                                        | Unbound already answers `zdk.no` / `code.zdk.no` → `10.10.30.1`; revisit only if clients bypass internal DNS |
| mDNS              | **Static IPs first**                                           | Avahi reflector servers↔IoT only if discovery fails             |
| Guest DNS         | **1.1.1.1 / 9.9.9.9**                                          | No Blocky on guest for v1                                       |
| IoT lab DNS       | **Deny** `*.lab.zdk.no` after Blocky (Stage 5)                 | Whitelist only if a device needs a name                         |
| Caddy LAN INPUT   | **trusted + servers + vpn** (`:80/:443`)                       | Not mgmt (infrastructure-only); not IoT/guest. WAN INPUT Stage 7 |
| Home Assistant    | **Docker on TrueNAS**, VLAN 30                                 | HA initiates to IoT; stays off IoT VLAN                         |
| TrueNAS compose   | **Single** `services/truenas/docker-compose.yml`               | HA, Forgejo, Authelia, Blocky (Caddy is on janus)               |
| Location          | **Norway**, ~60 m² flat                                        | 1 AP; EU/NO retailers where possible                            |

## Exposure matrix

| Hostname                 | WAN           | Authelia | Notes |
| ------------------------ | ------------- | -------- | ----- |
| `zdk.no`                 | Yes (Stage 7) | No       | Public app |
| `code.zdk.no`            | Yes (Stage 7) | No       | Forgejo; HTTPS git on WAN |
| `auth.lab.zdk.no`        | **No**        | No       | Authelia portal (would loop) |
| `code.lab.zdk.no`        | **No**        | No       | Forgejo-native auth (internal Git) |
| `headscale.lab.zdk.no`   | **No**        | No       | Tailscale login-server; Stage 6 |
| `unifi.lab.zdk.no`       | **No**        | Later    | Until Caddy vhost: `https://10.10.10.1:11443` |
| Other `*.lab.zdk.no`     | **No**        | Yes      | ha, grafana, capacitor, … |
| Future public apps       | Per-app       | Optional | Document a row here before WAN cutover |

## TLS (v1)

| Layer                                | Approach |
| ------------------------------------ | -------- |
| Public WAN (`zdk.no`, `code.zdk.no`) | Caddy ACME **DNS-01** (Domeneshop); `enableWanCaddy` still required to *serve* 80/443 |
| Internal (`*.lab.zdk.no`)            | Caddy ACME **DNS-01** (Domeneshop). Unbound → `10.10.30.1` for browsing; no public A/AAAA for `lab` names |
| Caddy → Traefik (east-west)          | HTTP on VLAN 30 — mTLS is a non-goal for v1 |
| step-ca                              | **Not in v1** — Caddy ACME covers edge; revisit for mTLS/device certs if needed |

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
