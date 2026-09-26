# net

Declarative home network configuration and documentation.

## Documentation

**[docs/plan.md](docs/plan.md)** — index of the docs and a short picture of the network as deployed. The Nix, RouterOS, and Kubernetes tree is the source of truth. Open follow-ups: **[docs/todo.md](docs/todo.md)**.

| Doc | Contents |
|-----|----------|
| [docs/decisions.md](docs/decisions.md) | Canonical decision log |
| [docs/vlan-plan.md](docs/vlan-plan.md) | VLANs, IPs, DHCP, DNS |
| [docs/firewall-matrix.md](docs/firewall-matrix.md) | nftables policy |
| [docs/inventory.md](docs/inventory.md) | Devices and reservations |
| [docs/architecture.md](docs/architecture.md) | Diagrams and service map |
| [docs/todo.md](docs/todo.md) | Open follow-ups on the live hosts |
| [docs/runbooks/](docs/runbooks/) | Operational procedures (restore, DNS, ACME, Capacitor) |
| [docs/decision-briefs.md](docs/decision-briefs.md) | Design options with recommendations |
| [docs/reference/](docs/reference/) | Alternatives not chosen |

**Public services:** `img.zdk.no` (Immich), `ha.zdk.no` (Home Assistant), and `code.zdk.no` (Forgejo) on TrueNAS via Caddy. Apex `zdk.no` is not a homelab site.

**Browser viewer:** from the repo root, `python3 scripts/generate-viewer.py --open`. That parses the markdown docs and READMEs and writes `docs/generated/index.html`. Markdown stays the source of truth.

**CI:** GitHub Actions (`.github/workflows/validate.yml`) runs `./scripts/validate.sh` on `main` and pull requests — Caddy fmt, exporter tests, `nix flake check`, router/nodes eval, kustomize. Locally the same script skips missing tools.

## Repo layout

`nodes/` is a NixOS flake (k3s on). DNSUpdater is the flake module on janus, not `services/dnsupdater/`.

```
net/
├── flake.nix      # NixOS configs (optiplex / janus)
├── docs/          # plan, decisions, vlan, firewall, inventory, runbooks, reference
├── router/        # janus NixOS modules
├── nodes/         # RK1 NixOS flake (nordri–vestri; k3s on)
├── switch/        # CRS310 RouterOS (L2 VLANs)
├── services/      # truenas compose, Caddy, Authelia, HA/Immich/Forgejo/Jellyfin READMEs, DNS, Promtail
├── k8s/           # Flux tree (infra HelmReleases)
├── secrets/       # .sops.yaml + encrypted router.yaml
└── scripts/       # validate.sh, generate-viewer.py
```
