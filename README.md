# net

Declarative home network configuration and documentation.

## Plan

See [docs/plan.md](docs/plan.md) for the full architecture plan, including VLAN design, NixOS router setup, Caddy/Traefik ingress, WireGuard VPN, and Prometheus/Grafana monitoring.

**Public services (Stage 7):** `zdk.no` ([Zdk](https://github.com/sknutsen/Zdk) on k8s) and `code.zdk.no` (Forgejo on TrueNAS). HTTPS-only Git over WAN; no WAN SSH.

**Browser viewer:** run `python3 -m http.server 8080` from the repo root, then open [docs/viewer.html](http://localhost:8080/docs/viewer.html).

## Repo layout (target)

```
net/
├── docs/          # plans, runbooks, firewall matrix
├── router/        # NixOS flake for DIY router
├── services/      # Caddy, Forgejo, Traefik, Prometheus, DNS, Authelia
├── k8s/           # Flux GitOps; apps/zdk/ ingress stub for zdk.no
├── secrets/       # sops/age encrypted secrets
└── scripts/       # validation helpers
```
