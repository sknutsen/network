# Auth: Authelia vs Authentik (reference)

**Chosen:** Authelia as a TrueNAS App on `10.10.30.20:9091`. See
[decisions.md](../decisions.md) and [the Authelia README](../../services/authelia/README.md).

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

Live deploy is the TrueNAS catalog App. Compose Authelia in
`services/truenas/docker-compose.yml` is reference only — do not start it
alongside the App.
