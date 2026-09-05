# Authelia

SSO / forward-auth for lab UIs. Live deploy is a **TrueNAS App** on
`10.10.30.20:9091`. Caddy on janus terminates TLS.

YAML in this directory is the intended config and the compose reference. Do
not start the Authelia service in `services/truenas/docker-compose.yml` — that
would bind the same host port.

## Hostname

| Hostname | WAN | Auth |
|----------|-----|------|
| `https://auth.lab.zdk.no` | No (split-horizon) | Portal (no `forward_auth` — would loop) |

Browse from trusted / servers / VPN (`10.10.0.0/16`). Caddy `lab_only` aborts
WAN. nftables drops forwarded `:9091`; do not open `https://10.10.30.20:9091`
from other VLANs.

Caddy `forward_auth` to this backend for other lab UIs except `auth` /
`code.lab` / `ha.lab` / `immich.lab` / `truenas.lab` / `unifi.lab` / (later)
`headscale.lab`. Public apps use native login.

## Login

File backend. Users live in the file the app mounts as
`/config/users_database.yml` (example: `zdk` in `users_database.yml.example`).
There is no default password. Hash:

```bash
docker run --rm authelia/authelia:4 \
  authelia crypto hash generate argon2 --password 'yourpassword'
```

Restart the app after editing users. First factor only (`one_factor` on
`*.lab.zdk.no`). TOTP is enabled but not required until a two-factor rule
exists.

Password-reset links go to the filesystem notifier (no SMTP yet). Read
`notification.txt` on the config volume.

## Storage (TrueNAS App)

The catalog app usually mounts writable `/config` and not `/data`. The
filesystem notifier parent directory must exist and be writable by the
container user (`apps` / 568, or the app User ID).

- Notifier: `/config/notification.txt` (not `/data/notification.txt` unless
  `/data` is mounted)
- SQLite (if used): `/config/db.sqlite3` or a mounted `/data`

`mkdir /data: permission denied` on the notification provider means the
notifier path is still `/data/...` with no writable `/data` mount.

Compose reference mounts `/mnt/tank/services/authelia/data:/data` and keeps
SQLite + notifier under `/data`.

## Secrets

`JWT_SECRET`, `SESSION_SECRET`, `STORAGE_ENCRYPTION_KEY` — see `.env.example`.
Set in the TrueNAS app environment (not committed).
