# Auth: Authelia vs Authentik (reference)

**Chosen:** Authelia on TrueNAS Docker. See [decisions.md](../decisions.md).

| Aspect | Authelia | Authentik |
|--------|----------|-----------|
| Role | Forward-auth gateway + light OIDC | Full IdP (OIDC/SAML/LDAP) |
| Caddy integration | Native `forward_auth` | Proxy provider or OIDC per app |
| Config | YAML in Git | Web UI + export |
| RAM | ~50–100 MB | ~500 MB–2 GB |
| Capacitor | `AUTH=trusted_proxy` — documented | More setup |

**When Authentik fits:** SAML, LDAP-as-IdP, multi-user self-service portal, visual flow builder.

**Repo layout (Authelia):**

```
services/authelia/
├── configuration.yml
├── .env.example              # copy → .env (not committed)
└── users_database.yml.example  # copy → users_database.yml (not committed)
```

Deployed via `services/truenas/docker-compose.yml`.
