# GitOps: Flux vs ArgoCD (reference)

**Chosen:** Flux + Capacitor (self-hosted). See [decisions.md](../decisions.md).

| Aspect | Flux | ArgoCD |
|--------|------|--------|
| UI | CLI-first; Capacitor for visuals | Rich built-in UI |
| Architecture | Modular controllers | Single app controller + UI |
| Resource usage | Lighter | Heavier (UI + redis) |
| Multi-cluster | Bootstrap per cluster | One ArgoCD, many clusters |
| Secrets | SOPS + age native | SOPS, Sealed Secrets, etc. |

**When ArgoCD fits:** Visual dashboard priority, multi-cluster single pane, team members prefer UI debugging.

**What Flux + Capacitor covers:** Kustomization/HelmRelease status, Git↔cluster diff, Helm rollback. Does not replace `kubectl logs` for arbitrary pods.

Running both Flux and ArgoCD together is unnecessary.
