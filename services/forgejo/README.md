# Forgejo

Self-hosted Git forge. Live deploy is a **TrueNAS App** on
`10.10.30.20:30142` (HTTP UI) and `:30143` (SSH). Caddy on janus terminates
TLS. Do not also start the Forgejo service in
`services/truenas/docker-compose.yml` — that would bind the same host ports.

## Hostnames

| Hostname | WAN | Auth |
|----------|-----|------|
| `https://code.lab.zdk.no` | No (split-horizon) | Forgejo-native |
| `https://code.zdk.no` | Stage 7 | Forgejo-native (vhost commented) |

| Port | Role |
|------|------|
| `30142` | UI / HTTPS git via Caddy |
| `30143` | LAN SSH (trusted + later VPN). Not WAN `:22` |

`ROOT_URL` / `SSH_DOMAIN` stay `https://code.lab.zdk.no` and `SSH_PORT=30143`
until Stage 7 (`code.zdk.no`).

## Git transport

- **WAN:** HTTPS only, when `code.zdk.no` is enabled
- **WAN SSH:** disabled — no WAN INPUT for `:22` or `:30143`
- **Trusted / VPN:** `git@code.lab.zdk.no:user/repo.git` via `:30143` (Caddy
  does not proxy SSH; clients use `10.10.30.20` or an SSH `Port 30143` /
  `Hostname` block)

nftables drops forwarded `:30142` so browsers cannot skip Caddy. `:30143` is
allowed from trusted (and VPN when Stage 6 is on).

## Stage 7 checklist

1. Disable open registration in Forgejo admin
2. Create admin account
3. Confirm router has **no WAN :22** (or `:30143`)
4. Include the TrueNAS App dataset in NAS backup snapshots
