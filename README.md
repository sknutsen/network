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
| [docs/decision-briefs.md](docs/decision-briefs.md) | Open decisions — briefs with recommendations |
| [docs/reference/](docs/reference/) | Alternatives not chosen |

**Public services (Stage 7):** `zdk.no` ([Zdk](https://github.com/sknutsen/Zdk) on k8s) and `code.zdk.no` (Forgejo on TrueNAS). HTTPS-only Git over WAN; LAN SSH on trusted VLAN + VPN.

**Browser viewer:** from the repo root, `python3 scripts/generate-viewer.py --open`. That parses the markdown and writes a standalone `docs/generated/index.html` you can open as a file (no HTTP server). Markdown stays the source of truth.

## Repo layout (target)

```
net/
├── docs/          # plan, decisions, vlan, firewall, inventory, reference
├── router/        # NixOS flake for DIY router
├── nodes/         # NixOS flake for RK1 cluster
├── services/      # truenas compose, Caddy, Authelia, DNS, DNSUpdater
├── k8s/           # Flux GitOps; apps/zdk/ ingress stub
├── secrets/       # sops/age encrypted secrets
└── scripts/       # validate.sh, generate-viewer.py
```
