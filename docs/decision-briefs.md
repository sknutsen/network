# Decision briefs

Design options and history. **Brief IDs in this file are canonical** — use
them in `plan.md` § Remaining decisions. Canonical choices:
[decisions.md](decisions.md).

Resolved briefs stay here as rationale (a **Decision** section). Unresolved
briefs still end with a recommendation. First-boot leftovers only:
[router/OPEN-QUESTIONS.md](../router/OPEN-QUESTIONS.md).

**For agents:** Closing a brief means update `decisions.md`, set **Status:
Resolved** here, and remove the row from `plan.md` § Remaining decisions.

| # | Brief | Status | Decide by |
|---|-------|--------|-----------|
| 1 | [IPv6 prefix size](#1-ipv6-prefix-size) | Install-time — ISP **OBOS Nett**; prefix TBD | Stage 2 |
| 2 | [NPTv6 vs native /64 per VLAN](#2-nptv6-vs-native-64-per-vlan) | Resolved | — |
| 3 | [`*.lab.zdk.no` TLS](#3-labzdkno-tls) | Resolved | — |
| 4 | [step-ca internal CA](#4-step-ca-internal-ca) | Resolved | — |
| 5 | [k8s API VIP](#5-k8s-api-vip) | Resolved | — |
| 6 | [Longhorn storage](#6-longhorn-storage) | Resolved | — |
| 7 | [Control-plane taint](#7-control-plane-taint) | Resolved | — |
| 8 | [Zdk repo boundary](#8-zdk-repo-boundary) | Resolved | — |
| 9 | [Blocky host placement](#9-blocky-host-placement) | Resolved | — |
| 10 | [CGNAT verification](#10-cgnat-verification) | Resolved | — |
| 11 | [Hardware capability check](#11-hardware-capability-check) | Install-time — do at Stage 1 | Stage 1 |
| 12 | [RK1 BSP / NPU fork](#12-rk1-bsp--npu-fork) | Deferred | When NPU/GPU needed |
| 13 | [Nintendo Switch local play](#13-nintendo-switch-local-play) | Deferred | If local play fails |
| 14 | [Hairpin NAT](#14-hairpin-nat) | Resolved — off | — |
| 15 | [CrowdSec](#15-crowdsec) | Resolved | — |
| 16 | [mDNS / Avahi reflector](#16-mdns--avahi-reflector) | Resolved — static IPs first | Stage 4–5 if discovery fails |
| 17 | [Trusted → IoT cast rules](#17-trusted--iot-cast-rules) | Resolved — wait for HA | Stage 4–5 |
| 18 | [Future public apps](#18-future-public-apps) | Per-app — Immich + HA documented | Each new WAN service |
| 19 | [Guest DNS via Blocky](#19-guest-dns-via-blocky) | Resolved — public resolvers | Post Stage 4 if wanted |

---

## 1. IPv6 prefix size

**Status:** Install-time — document in [vlan-plan.md](vlan-plan.md) at Stage 2.

### Context

Norwegian ISPs typically delegate a `/56` or `/48` via DHCPv6-PD on the WAN
link. Prefix size determines how many `/64` subnets you can carve for VLANs,
WireGuard, and future growth. This is observational — layout is already
**native /64 per VLAN** (#2). If the prefix is `/60` or smaller, revisit NPTv6.

### What to record

| Field | Example |
|-------|---------|
| Delegated prefix | `2a0x:yyyy::/56` |
| ISP | **OBOS Nett** (recorded); prefix size still blank |
### How to capture

1. Enable PD on WAN in Stage 2 router config.
2. Read `dhcpcd` / `networkd` logs or `ip -6 addr show dev wan`.
3. Fill the table in [vlan-plan.md § IPv6](vlan-plan.md).

### Recommendation

No decision required — **document what the ISP gives you**. If the prefix is
smaller than `/60`, prefer NPTv6 (#2) to conserve addresses.

---

## 2. NPTv6 vs native /64 per VLAN

**Status:** **Resolved** — native /64 per VLAN (accepted default).

### Context

Each VLAN needs IPv6 for trusted devices, servers, IoT, and guest. Layout is
documented in [vlan-plan.md](vlan-plan.md) (example subnets from `/56`
delegation).

### Decision

| Setting | Value |
|---------|-------|
| Layout | **Native /64 per VLAN** — distinct subnet per VLAN interface |
| Addressing | Router advertises RA on each VLAN; per-VLAN firewall rules |
| WAN inbound | **Default deny** (already decided) |
| NPTv6 | **Not in v1** — revisit only if ISP delegates `/60` or smaller |
| Prefix size | Document actual delegation at Stage 2 — see [brief #1](#1-ipv6-prefix-size) |

### Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Native /64 per VLAN** ✓ | Straightforward RA + forwarding; easy firewall per VLAN; matches vlan-plan | Uses more of delegated prefix |
| **NPTv6** | Hides internal layout; prefix changes without renumbering | nftables NPT rules; harder debugging |
| **IPv4-only lab (defer v6)** | Zero v6 complexity | Loses v6 egress; no public ingress over v6 |

---

## 3. `*.lab.zdk.no` TLS

**Status:** **Resolved** — Caddy ACME **DNS-01 via Domeneshop** (v1 path).

### Context

Internal hostnames (`grafana.lab.zdk.no`, `capacitor.lab.zdk.no`, etc.) are
**split-horizon only** — never WAN-reachable. Browsers still need trusted TLS.
Let's Encrypt HTTP-01 queries **public** DNS, so it cannot issue certs for names
that do not exist on Domeneshop. Unbound still answers `*.lab.zdk.no` → Caddy
for *browsing*; ACME does not use that path.

### Decision

| Setting | Value |
|---------|-------|
| Issuer | Let's Encrypt via Caddy ACME |
| Challenge | **DNS-01** via Domeneshop (`dns.providers.domainnameshop`) |
| DNS (browse) | Unbound: `*.lab.zdk.no` → `10.10.30.1` (Caddy on janus) |
| Public DNS | **No** A/AAAA for `*.lab.zdk.no` (temporary TXT only during issuance) |
| Secrets | Domeneshop API token + secret in sops (same API user as DNSUpdater is fine) |
| Caddy build | `pkgs.caddy.withPlugins` + `github.com/caddy-dns/domainnameshop` (hash filled on first Linux build) |
| Port 80 | Not required for ACME; still served for HTTP→HTTPS once Caddy is up |
| Public names | Same DNS-01 issuer at Stage 7; `enableWanCaddy` is for *serving*, not issuance |

### Options considered

| Option | How it works | Pros | Cons |
|--------|--------------|------|------|
| **(a) Split-horizon HTTP-01** | Unbound returns Caddy LAN IP; Caddy completes HTTP-01 locally | No DNS API secrets | Let's Encrypt looks up the name on **public** DNS — fails with no `lab` records |
| **(b) DNS-01 via Domeneshop API** ✓ | TXT records via Domeneshop API | Works with no public A records; wildcard-capable; works behind closed WAN 80 | API token in sops; needs a Caddy build with the Domeneshop module |
| **(c) step-ca internal CA** | Private CA | Full control | Ruled out for v1 — see [brief #4](#4-step-ca-internal-ca) |

---

## 4. step-ca internal CA

**Status:** **Resolved** — not in v1 (accepted default).

### Context

[Smallstep step-ca](https://smallstep.com/docs/step-ca/) can issue short-lived
certs for internal services and mTLS between components. Caddy handles edge TLS
for v1.

### Decision

**Skip step-ca for v1.** Caddy ACME covers WAN and internal (`*.lab.zdk.no`)
certs. Caddy → Traefik stays HTTP on VLAN 30 (mTLS non-goal for v1).

Revisit step-ca if you add mTLS east-west, issue certs to non-browser clients,
or split-horizon ACME becomes painful. If adopted later: TrueNAS Docker or k8s;
root cert via SOPS-backed offline ceremony; document rotation in runbooks.

### Options considered

| Option | When it fits |
|--------|--------------|
| **Skip step-ca (v1)** ✓ | Caddy ACME covers edge; Caddy → Traefik stays HTTP on VLAN 30 |
| **Deploy step-ca later** | mTLS east-west, device certs, or avoiding DNS API for internal names |
| **step-ca replaces ACME for `*.lab.zdk.no`** | Ruled out for v1 — pair with brief #3(c) only if step-ca is adopted later |

---

## 5. k8s API VIP

**Status:** **Resolved** — direct `10.10.30.11:6443`; reserve `.10` (accepted default).

### Context

`10.10.30.10` is reserved in [vlan-plan.md](vlan-plan.md). k3s control plane
runs on `nordri` at `10.10.30.11`. A floating VIP lets `kubectl` survive CP node
migration or a second control plane.

### Decision

| Setting | Value |
|---------|-------|
| API endpoint | `https://10.10.30.11:6443` |
| kube-vip | **Not in v1** |
| `10.10.30.10` | Reserved in DHCP/DNS for future kube-vip |
| Flux / kubeconfig | Server URL points at `10.10.30.11` |

Add kube-vip at `.10` only when promoting a **second control plane** or
automating CP failover.

### Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Direct `10.10.30.11:6443`** ✓ | Zero moving parts; matches single-CP homelab | API address changes if CP moves |
| **Reserve `.10`, add kube-vip later** | IP ready for second CP or failover | Deferred complexity |
| **kube-vip from day one** | Stable `kubectl` endpoint at `.10` | Overkill for one CP; ARP/L2 considerations on VLAN 30 |

---

## 6. Longhorn storage

**Status:** **Resolved** — default StorageClass, replica 3 (accepted default).

### Context

Longhorn is the chosen k8s StorageClass ([decisions.md](decisions.md)). Four
RK1 nodes with 256 GB+ NVMe each at `/var/lib/longhorn`. Each volume replicates
to three nodes.

### Decision

| Setting | Value |
|---------|-------|
| Default StorageClass | Longhorn |
| Replica count | **3** |
| Data path | `/var/lib/longhorn` on NVMe (all four RK1s) |
| Min disk per node | 256 GB |
| Off-cluster backup | Velero or TrueNAS ZFS snapshots |

Usable replicated capacity: roughly one node's worth (~256 GB) after overhead —
sufficient for homelab Prometheus/Loki/Zdk.

### Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Default replica count 3** ✓ | Survives loss of one node; good durability | ~3× space amplification |
| **Replica count 2** | Less space; OK for homelab with backups | Single node failure + another degraded = data risk |
| **Replica count 1** | Maximum capacity | No redundancy — unacceptable for Prometheus/Loki without external backup |
| **Different StorageClass per tier** | `longhorn-3` for critical; `longhorn-1` for cache | More manifest complexity |

### Stage 5 checklist

1. Mount NVMe at `/var/lib/longhorn` on all four RK1s.
2. Deploy Longhorn; set `defaultReplicaCount: 3`.
3. Configure Velero or ZFS snapshots on TrueNAS for off-cluster backup.

---

## 7. Control-plane taint

**Status:** **Resolved** — keep default CP taint on `nordri` (accepted default).

### Context

k3s control plane on `nordri` (8 GB RAM class RK1). Default k3s taints CP node
`NoSchedule` for non-control-plane pods. Workers `sudri`–`vestri` run
Traefik, monitoring, and apps.

### Decision

**Keep the default CP taint on `nordri`.** Do not schedule app workloads on the
control plane. `sudri`–`vestri` run Traefik, kube-prometheus-stack, Capacitor,
and Zdk.

Revisit only if `kubectl top nodes` shows sustained worker pressure and CP RAM
sits idle.

### Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Keep CP taint (default)** ✓ | Protects API/etcd from app memory pressure; clear separation | Only 3 worker nodes for workloads |
| **Remove taint, schedule on CP** | +1 node's CPU/RAM for pods | API latency or OOM on CP affects entire cluster |
| **Taint with tolerated system pods only** | Longhorn manager on all nodes; apps on workers | Slightly more YAML |

---

## 8. Zdk repo boundary

**Status:** **Resolved** — Flux `GitRepository` + `Kustomization` → Zdk repo
(accepted default).

### Context

`net/` owns platform: router, VLANs, Caddy edge, Flux bootstrap, ingress stub.
Zdk application code and container image live in an external repo. Stage 7 WAN
for `zdk.no` depends on this boundary.

### Decision

| Repo | Owns |
|------|------|
| **[Zdk](https://github.com/sknutsen/Zdk)** | Deployment, Service, image CI, env ConfigMaps, app secrets (SOPS or ExternalSecrets) |
| **`net/`** | `k8s/clusters/homelab/apps/zdk/ingressroute.yaml` (Traefik `IngressRoute` stub), Flux `GitRepository` + `Kustomization` CR, Caddy `zdk.no` → Traefik LB |

Manifest path in Zdk repo: `deploy/` or `k8s/` — to be agreed when Zdk ships
deploy spec.

### Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Flux pulls Zdk repo** (`GitRepository` + `Kustomization`) ✓ | App team owns image tag and Deployment; platform repo stays thin | Two repos to coordinate; need image pull secret in k8s |
| **Copy manifests into `net/k8s/.../apps/zdk/`** | Single-repo GitOps | Duplication; drift from app repo |
| **Helm chart from OCI/registry** | Versioned releases | More packaging overhead for one app |

---

## 9. Blocky host placement

**Status:** **Resolved** — TrueNAS Docker at `10.10.30.21`.

### Context

Blocky filters DNS for IoT VLAN ([decisions.md](decisions.md)). IoT clients are
redirected to Blocky via dnsmasq/Unbound policy. Needs stable IP and low
latency.

### Options

| Option | Pros | Cons |
|--------|------|------|
| **TrueNAS Docker at `10.10.30.21`** | Co-located with compose stack; simple upgrades; matches vlan-plan | TrueNAS reboot affects IoT DNS |
| **k8s Deployment on workers** | GitOps lifecycle; restarts isolated from TrueNAS | Circular dependency if cluster DNS unresolved during bootstrap |
| **Router container** | Always up with DHCP | Mixes DNS policy with router; NixOS container overhead |

### Decision

**TrueNAS Docker at `10.10.30.21`** — already in [vlan-plan.md](vlan-plan.md)
and `services/truenas/docker-compose.yml`. Revisit k8s only if TrueNAS
availability for DNS becomes a measured problem.

---

## 10. CGNAT verification

**Status:** Resolved — CGNAT is **not active**. Dynamic public IPv4 confirmed.

### Context

Plan uses **dynamic public IPv4** with **WAN INPUT to Caddy** (80/443) plus
WireGuard UDP ([decisions.md](decisions.md)). Recorded in
[vlan-plan.md § IPv6](vlan-plan.md). Fallback if the ISP later moves the link
behind CGNAT: [reference/cgnat-options.md](reference/cgnat-options.md).

### Decision

No further action. Stage 7 opens WAN INPUT to Caddy on janus — not DNAT to
TrueNAS.

---

## 11. Hardware capability check

**Status:** Install-time — physical verification at Stage 1 (not a design choice).

### Context

Design assumes specific NIC roles, switch VLAN support, and AP SSID mapping.
Wrong assumptions force redesign. MACs and port plan are already written down;
this brief is “prove them on the metal.”

### What to do (Stage 1, in order)

1. **Label** CRS310 ports 1–8 per [inventory.md](inventory.md) / vlan-plan.
2. **Cable the LAN side first** (no ISP cutover yet): i350 port 1 → CRS310 ether1
   trunk; AP + PoE injector → ether2; TrueNAS → ether4; Turing Pi → ether3.
3. **After NixOS first boot**, confirm names match MACs:
   `ip link` shows `wan0` / `lan0` / `spare0`; `ethtool -p lan0` blinks i350
   **port 1** (or unplug test). Spare stays down.
4. **Import** [switch/crs310.rsc](../switch/crs310.rsc); check mgmt `10.10.10.2`
   and that a tagged client on ether1 lands in the right VLAN.
5. **Bridge the OBOS Nett modem** at router cutover, then plug it into `wan0`.
   Confirm public IPv4 DHCP on `wan0` (whatismyip matches the WAN address).
6. **UniFi / AP** — UniFi OS Server is **functional** on the router. Adopt U7
   Lite; SSIDs → VLANs 20/40/50. Confirm a phone on each SSID gets the matching
   `10.10.x.0/24`.
7. Document any deviation in [inventory.md](inventory.md).

### Verify

| Component | Requirement | How |
|-----------|-------------|-----|
| OptiPlex 9020 MT | I217LM = WAN; i350-T2 port 1 = 802.1Q trunk | `ip link`, `ethtool -p lan0` |
| CRS310 | 802.1Q VLAN, trunk + access ports per vlan-plan | Import `.rsc`; ping `10.10.10.2` |
| U7 Lite | SSIDs mapped to VLANs 20/40/50 | UniFi OS Server; DHCP subnet check |
| Turing Pi 2.5 | Single NIC on VLAN 30 access | Link on port 3 |
| TrueNAS | NIC on VLAN 30 access | Static `10.10.30.20` |

---

## 12. RK1 BSP / NPU fork

**Status:** Deferred — [plans/rk1-bsp-fork.md](plans/rk1-bsp-fork.md).

### Context

GiyoMoon NixOS mainline is the default RK1 OS. Turing's NPU/GPU needs a vendor
BSP kernel — not required for k3s, Traefik, or Zdk.

### Options

| Option | When |
|--------|------|
| **Stay on mainline (default)** | General-purpose k8s workloads |
| **BSP fork** | ONNX/ML inference on NPU, hardware video encode |
| **Escape to Ubuntu vendor image** | Fastest path to NPU; see [escape-hatches](reference/escape-hatches-ubuntu-talos.md) |

### Recommendation

**Defer BSP fork** until a workload explicitly needs NPU/GPU. Initial cluster
on GiyoMoon mainline per [decisions.md](decisions.md).

---

## 13. Nintendo Switch local play

**Status:** Deferred — [inventory.md](inventory.md), [firewall-matrix.md](firewall-matrix.md).

### Context

Switch is on IoT VLAN (`10.10.40.14`) for online gaming. **Local wireless
play** (trusted VLAN ↔ Switch) may need L2 discovery or firewall holes Nintendo
does not document clearly.

### Options

| Option | Pros | Cons |
|--------|------|------|
| **Do nothing (default)** | Strict segmentation | Local play may fail |
| **Firewall: trusted → Switch IP** on specific UDP ports | Targeted | Trial-and-error per game |
| **Move Switch to trusted VLAN** | Best local play compatibility | IoT exposure; HA integration harder |
| **Temporary VLAN bypass rule** | Play session only | Operational hassle |

### Recommendation

**Defer** until local play is tested. If needed, add **trusted → `10.10.40.14`
UDP** rules per Nintendo troubleshooting guides before moving VLANs.

---

## 14. Hairpin NAT

**Status:** **Resolved** — off.

### Context

Split-horizon DNS sends internal clients to `10.10.30.1` (Caddy on janus) for internal names.
Public names (`zdk.no`) may resolve to WAN IP from some clients. Hairpin NAT
lets LAN clients reach WAN IP:443 on the router's public address.

### Options

| Option | When |
|--------|------|
| **Disable (default)** | Internal DNS never returns public IP for services you test from LAN |
| **Enable hairpin NAT** | `curl https://zdk.no` from LAN hits public IP and fails without loopback |
| **Split-horizon for public names too** | LAN clients get `10.10.30.1` for `zdk.no` — reduces hairpin need |

### Decision

**Off.** Split-horizon for the public names is **already implemented:** Unbound
`local-data` answers `zdk.no` and `code.zdk.no` → `10.10.30.1` (Caddy). LAN
`curl https://zdk.no` should hit Caddy without hairpin NAT. Enable hairpin only
if a client bypasses internal DNS and resolves the WAN address.

---

## 15. CrowdSec

**Status:** **Resolved** — not in v1 (accepted default).

### Context

Once `zdk.no` and `code.zdk.no` are WAN-facing, Caddy logs may show scan and
brute-force noise. CrowdSec is a collaborative IDS with bouncers (e.g. Caddy
plugin or firewall).

### Decision

**Skip CrowdSec at Stage 7 launch.** Use **nftables rate limits** on WAN 443 as
the first line of defense. Deploy CrowdSec + Caddy bouncer only if access logs
show sustained 403/401 brute force after the first month of WAN exposure.

### Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Skip v1** ✓ | Simpler edge | No automated ban of noisy IPs |
| **CrowdSec + Caddy bouncer** | Automated remediation | Another compose service; community lists phone home |
| **nftables rate-limit only** | Router-level; no new agent | Less context-aware — use as v1 default |

---

## 16. mDNS / Avahi reflector

**Status:** **Resolved** — static IPs first (accepted default).

### Context

IoT and servers are on separate VLANs. mDNS does not cross routers by default.
Home Assistant on servers VLAN initiates to IoT; HA is **not** moved to IoT
([decisions.md](decisions.md)).

### Options

| Option | Pros | Cons |
|--------|------|------|
| **Static IPs only (default)** | No multicast across VLANs; explicit firewall | Manual HA device entries |
| **Avahi reflector router, servers ↔ IoT only** | Discovery for casting/HA | Multicast amplification; scope carefully |
| **Wide reflection to trusted** | Easiest casting | Leaks IoT device names to trusted VLAN |

### Decision

**Static IPs in HA** per [inventory.md](inventory.md). Enable **scoped Avahi
reflector** (VLAN 30 ↔ 40 only) only if discovery fails for casting or HA
auto-detection. Never reflect to guest or trusted broadly.

---

## 17. Trusted → IoT cast rules

**Status:** **Resolved** — wait until Stage 4–5 / HA.

### Context

Phones/laptops on trusted VLAN cast to TV, Chromecast, Odyssey on IoT.
[targeted firewall rules](firewall-matrix.md) may work without mDNS reflection.

### Options

| Option | When |
|--------|------|
| **No extra rules** | Casting works with static IPs + existing servers→IoT policy |
| **Allow trusted → specific IoT IPs** (TCP/UDP cast ports) | Discovery fails but IP-based cast works |
| **mDNS reflection (#16)** | Apps require discovery by name |

### Decision

**Do not open cast rules at Stage 3.** Stage 3 is subnet placement only. At
Stage 4–5 / when HA is up, add **per-device allows** (trusted → TV, Chromecast,
Odyssey) before any Avahi reflector. Document each target in firewall-matrix.

---

## 18. Future public apps

**Status:** Per-app — Immich and Home Assistant documented below.

### Context

Public apps terminate TLS on Caddy and use **native** login (no Authelia).
`*.lab.zdk.no` is never in public DNS. Caddy `lab_only` aborts WAN clients that
guess a lab Host header.

### Decision checklist (per app)

| Question | Guidance |
|----------|----------|
| WAN required? | Default **no** — VPN + `*.lab.zdk.no` first |
| Hostname | Subdomain of `zdk.no` (lab name stays `*.lab.zdk.no`) |
| Auth | Public app → no Authelia; admin UI → internal only |
| Backend | TrueNAS Docker vs k8s IngressRoute |
| DNS | Domeneshop + DNSUpdater; no `lab` public records |
| Firewall | nftables WAN → Caddy only on 443/80 |

### Documented apps

| Public name | Lab name | Backend | Auth |
|-------------|----------|---------|------|
| `img.zdk.no` | `immich.lab.zdk.no` | Immich `:30041` on TrueNAS | Immich-native |
| `ha.zdk.no` | `ha.lab.zdk.no` | Home Assistant `:30103` | HA-native |

Public certs are **HTTP-01** until the Domeneshop DNS-01 plugin is packaged.
Lab names stay `tls internal`.

### Recommendation

**Copy the two-tier pattern:** Caddy on janus for TLS/WAN; backend on k8s or
compose. Document each app as a row in decisions.md exposure matrix before
WAN cutover.

---

## 19. Guest DNS via Blocky

**Status:** **Resolved** — public resolvers for v1.

### Context

Guest VLAN DNS currently goes to **1.1.1.1 / 9.9.9.9** ([plan.md](plan.md)).
Blocky could offer logging, malware blocklists, or captive-portal-friendly
filtering for guests.

### Options

| Option | Pros | Cons |
|--------|------|------|
| **Public resolvers (default)** | Simple; no guest dependency on homelab | No visibility; guests bypass your policy |
| **Blocky guest profile** | Unified filtering stack | Guest traffic through TrueNAS; privacy considerations |
| **Router dnsmasq forward to Blocky** | Centralized | Guest isolation rules more complex |

### Decision

**Keep 1.1.1.1 / 9.9.9.9 for v1.** Revisit if you want guest query logging or
family-safe filtering on the guest SSID.

---

## Quick reference

| Topic | Default |
|-------|---------|
| IPv6 layout | **Resolved:** Native /64 per VLAN from delegated `/56` |
| Internal TLS | **Resolved:** Caddy ACME DNS-01 (Domeneshop) |
| step-ca | **Resolved:** Not in v1 |
| k8s API | **Resolved:** `10.10.30.11:6443`; reserve `.10` |
| Longhorn | **Resolved:** Replica 3; NVMe at `/var/lib/longhorn` |
| CP taint | **Resolved:** Keep on `nordri` |
| Zdk | **Resolved:** Flux → external Zdk repo |
| Blocky | **Resolved:** TrueNAS Docker `10.10.30.21` |
| CGNAT | **Resolved:** Not active; WAN INPUT to Caddy OK |
| Hairpin NAT | **Resolved:** Off |
| CrowdSec | **Resolved:** Not in v1; nftables rate-limit first |
| mDNS | **Resolved:** Static IPs first; Avahi only if discovery fails |
| Cast rules | **Resolved:** Wait for Stage 4–5 / HA |
| Guest DNS | **Resolved:** Public resolvers |
| Headscale | **Resolved:** Janus, `127.0.0.1:8081`, Caddy `headscale.lab.zdk.no` (not :8080) |
| ISP | **OBOS Nett**; PD at Stage 2; modem bridge at cutover |

After each decision is made, update [decisions.md](decisions.md) and remove the
matching row from [plan.md § Remaining decisions](plan.md#remaining-decisions).
