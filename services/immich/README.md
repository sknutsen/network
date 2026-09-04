# Immich

Photo library on TrueNAS Docker. Deployed via `services/truenas/docker-compose.yml`.
Caddy on janus terminates TLS.

## Hostnames

| Hostname | WAN | Auth |
|----------|-----|------|
| `https://immich.lab.zdk.no` | No (split-horizon) | Immich-native |
| `https://img.zdk.no` | Yes | Immich-native |

Do not put Authelia in front — the mobile app and API would break. Point the
app at **`https://img.zdk.no`**; Unbound answers that name with Caddy on LAN,
so one URL works at home and away.

## Port

Caddy → `10.10.30.20:30041` (TrueNAS App host port; Immich inside the
app still listens on 2283). nftables drops forwarded `:30041` so clients
cannot skip Caddy. Keep a **single** listener on that address.

## Data

| Path | Role |
|------|------|
| `/mnt/tank/services/immich/upload` | Photos / original files |
| `/mnt/tank/services/immich/postgres` | Postgres (local ZFS dataset, not NFS) |

Create the datasets, then:

```bash
cp services/immich/.env.example services/immich/.env
# set DB_PASSWORD and POSTGRES_PASSWORD to the same random alnum string
```

Upgrade images against the [current official compose](https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml).

## Public DNS

Domeneshop `A` (and `AAAA` if used) for **`img`**. No public record for
`immich.lab.zdk.no`. In Immich admin, set the external domain to
`https://img.zdk.no`.
