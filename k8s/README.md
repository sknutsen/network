# Kubernetes (Flux)

GitOps tree for the RK1 k3s cluster. Nodes: [nodes/README.md](../nodes/README.md).
Decisions: [docs/decisions.md](../docs/decisions.md).

Caddy on janus is the TLS edge. Traefik on MetalLB `10.10.30.100:80` is
in-cluster HTTP only. Authelia stays on Caddy, not in this tree.

## Layout

```
k8s/clusters/homelab/
├── kustomization.yaml    # required: only flux-system + the three Kustomization CRs
├── flux-system/          # created by `flux bootstrap` — do not hand-write
├── infra-core.yaml       # Flux Kustomization → infra/core
├── infra-config.yaml     # pools, IngressRoutes, Loki LB (needs CRDs)
├── apps.yaml             # Flux Kustomization → apps
├── infra/core/           # HelmRepos + HelmReleases + Capacitor OCI
├── infra/config/
└── apps/zdk/             # IngressRoute stub + suspended Zdk GitRepository
```

`flux bootstrap` writes `gotk-components.yaml` / `gotk-sync.yaml` under
`flux-system/`. Do not invent those files. After bootstrap, the
`flux-system` Kustomization builds this directory. The root
`kustomization.yaml` must exist and must list `flux-system` plus
`infra-core.yaml` / `infra-config.yaml` / `apps.yaml`. Without it,
kustomize-controller applies `infra/config` immediately (MetalLB CRDs
are not installed yet). `--token-auth` stores the GitHub PAT in
`flux-system/flux-system` (HTTPS); `gh` OAuth tokens cannot create
deploy keys.

## Bootstrap

Done on `main` (`--token-auth`). API is `https://10.10.30.11:6443`. Keep
the control-plane taint on nordri. Re-run only on a new cluster:

```bash
# kubeconfig from nordri:
#   sudo cat /etc/rancher/k3s/k3s.yaml
# rewrite server to https://10.10.30.11:6443

flux bootstrap github \
  --owner=sknutsen \
  --repository=network \
  --branch=main \
  --path=k8s/clusters/homelab \
  --personal
```

Needs a GitHub token with repo scope. The remote is
`github.com/sknutsen/network` (this working copy is named `net`).

Order after bootstrap: MetalLB → Longhorn + Traefik → Loki +
kube-prometheus-stack → Capacitor → `infra-config` → `apps`.

## What this deploys

| Component | How | Notes |
|-----------|-----|--------|
| MetalLB | Helm `0.16.1` | L2 pool `10.10.30.100–110`; FRR off |
| Traefik | Helm `41.4.0` | LB `10.10.30.100`; `web` only |
| Longhorn | Helm `1.12.1` | default SC, replica 3, `/var/lib/longhorn` |
| kube-prometheus-stack | Helm `88.6.0` | Prometheus, Grafana, Alertmanager |
| Loki | Helm `7.3.0` (sibling) | stack chart does not ship Loki; push `10.10.30.101:3100` |
| Capacitor | OCI `ghcr.io/gimlet-io/capacitor-manifests` | in-cluster UI; Caddy `capacitor.lab.zdk.no` |
| Zdk | IngressRoute + suspended GitRepository | app manifests stay in the Zdk repo |

Loki is a **sibling** HelmRelease, not part of kube-prometheus-stack. Promtail
on TrueNAS pushes to `.101:3100` — no Authelia.

Chart node-exporter is **off**. Scrapes NixOS exporters on janus
(`:9100`, presence `:9101`, unpoller `:9130`, snmp-exporter `:9116` →
CRS310) and the four RK1s, plus Blocky (`10.10.30.21:4000/metrics`).

Grafana sidecar loads `grafana-dashboard-network` (folder **Network**).
Alertmanager is `alertmanager.lab.zdk.no` (Authelia). Rules:
`infra/core/network-alerts.yaml`.

## Hosts / IngressRoutes

Caddy already sends `Host` to Traefik `.100`. Traefik routes:

| Host | Backend |
|------|---------|
| `grafana.lab.zdk.no` | `kube-prometheus-stack-grafana:80` (Caddy Authelia; Grafana form off) |
| `alertmanager.lab.zdk.no` | `kube-prometheus-stack-alertmanager:9093` (Caddy Authelia) |
| `capacitor.lab.zdk.no` | `capacitor.flux-system:9000` (Caddy Authelia) |
| `zdk.no` | `zdk.default:80` (502 until the Zdk repo ships) |

## Zdk

`apps/zdk/gitrepository.yaml` is **suspended** until
[sknutsen/Zdk](https://github.com/sknutsen/Zdk) publishes a deploy path.
Unsuspend and set `spec.path` when that exists. Do not copy Deployments into
`net/`.

## ARM64

Images must be `linux/arm64`. Pin bumps: `docker manifest inspect <image>`.
k3s on NixOS: [nixpkgs#495013](https://github.com/NixOS/nixpkgs/issues/495013).

## Check overlays (no cluster)

```bash
kubectl kustomize k8s/clusters/homelab/infra/core
kubectl kustomize k8s/clusters/homelab/infra/config
kubectl kustomize k8s/clusters/homelab/apps
```

`scripts/validate.sh` runs the same builds when `kubectl` or `kustomize` exists.
