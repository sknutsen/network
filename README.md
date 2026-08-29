# net

Declarative home network configuration and documentation.

## Plan

**[docs/plan.md](docs/plan.md)** — executive overview and doc map.

| Doc | Contents |
|-----|----------|
| [docs/decisions.md](docs/decisions.md) | Canonical decision log |
| [docs/vlan-plan.md](docs/vlan-plan.md) | VLANs, IPs, DHCP, DNS |
| [docs/firewall-matrix.md](docs/firewall-matrix.md) | nftables policy |
| [docs/inventory.md](docs/inventory.md) | Devices and reservations |
| [docs/architecture.md](docs/architecture.md) | Diagrams and service map |
| [docs/implementation-stages.md](docs/implementation-stages.md) | Stage 0–8 checklists |
| [docs/decision-briefs.md](docs/decision-briefs.md) | Design options with recommendations |
| [router/OPEN-QUESTIONS.md](router/OPEN-QUESTIONS.md) | Unanswered first-boot leftovers |
| [docs/reference/](docs/reference/) | Alternatives not chosen |

**Public services (Stage 7):** `zdk.no` ([Zdk](https://github.com/sknutsen/Zdk) on k8s) and `code.zdk.no` (Forgejo on TrueNAS). HTTPS-only Git over WAN; LAN SSH on trusted VLAN + VPN.

**Browser viewer:** from the repo root, `python3 scripts/generate-viewer.py --open`. That parses **all** markdown in the plan (docs, READMEs, remaining questions) and writes `docs/generated/index.html`. Markdown stays the source of truth.

## Target repo layout

`nodes/` is a NixOS flake (k3s off until Stage 5). DNSUpdater is a Nix stub, not `services/dnsupdater/`.

```
net/
├── flake.nix      # NixOS configs (optiplex / janus)
├── docs/          # plan, decisions, vlan, firewall, inventory, reference
├── router/        # janus NixOS modules
├── nodes/         # RK1 NixOS flake (nordri–vestri; k3s off)
├── switch/        # CRS310 RouterOS (L2 VLANs)
├── services/      # truenas compose, Caddy, Authelia, DNS, Promtail
├── k8s/           # Zdk IngressRoute stub; Flux bootstrap later
├── secrets/       # examples + .sops.yaml; live yaml not committed
└── scripts/       # validate.sh, generate-viewer.py
```
