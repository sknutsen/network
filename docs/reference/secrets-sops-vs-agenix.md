# Secrets: sops-nix vs agenix (reference)

**Chosen:** sops-nix + age. See [decisions.md](../decisions.md).

| Aspect | agenix | sops-nix |
|--------|--------|----------|
| Encryption | age (one file per secret) | Mozilla SOPS (multi-key YAML/JSON) |
| NixOS | `age.secrets` | `sops.secrets` |
| Flux/K8s | Separate SOPS setup | **Same SOPS files** as Flux |
| Non-NixOS | Manual `age -d` | `sops` CLI for Caddy deploy scripts |

**When agenix fits:** Router-only secrets, simplest NixOS workflow, happy with two systems (agenix + SOPS for Flux).

**Repo layout (sops-nix):**

```
secrets/
├── .sops.yaml
├── router.yaml.example
├── cluster.yaml.example  # pointer only — do not put the k3s token here
├── router.yaml           # encrypted (Caddy Domeneshop + future WG/DDNS)
nodes/secrets/cluster.yaml                    # k3s token (sops-nix on RK1s)
k8s/clusters/homelab/infra/core/*.secret.yaml # Flux sops (Grafana admin)
```
