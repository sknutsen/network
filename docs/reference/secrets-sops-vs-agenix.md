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
├── router.yaml
└── cluster.yaml
```
