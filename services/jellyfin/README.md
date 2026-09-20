# Jellyfin

Media server. Live deploy is a **TrueNAS App** on `10.10.30.20:30013`.
Caddy on janus terminates TLS. Do not also start Jellyfin in
`services/truenas/docker-compose.yml`.

## Hostname

| Hostname | WAN | Who | Auth |
|----------|-----|-----|------|
| `https://jellyfin.lab.zdk.no` | No (split-horizon) | Trusted, VPN, guest, Samsung TV (`10.10.40.10`) | Jellyfin-native |

One URL for every client. Not on WAN (unlike Immich / HA / Forgejo). Guest
resolves the name to `10.10.50.1` (Caddy on the guest gateway — survives
UniFi client isolation). The TV resolves it to `10.10.40.1` via Blocky
(Caddy on the IoT gateway — same isolation reason as guest).
Neither sees the rest of `*.lab.zdk.no`. Caddy `household` aborts other
source IPs.

Do not put Authelia in front — the TV app and mobile clients would break.

## Port

Caddy → `10.10.30.20:30013` (TrueNAS App HTTP). nftables drops forwarded
`:30013` so clients cannot skip Caddy.

## Jellyfin networking

Dashboard → Networking:

- Published server URL: `https://jellyfin.lab.zdk.no`
- Known proxies: `10.10.30.1`

On the Samsung TV (IoT SSID), add that URL in the Jellyfin app. Guest
phones use the same URL after joining `Hai-Fi Wai-Fi (Guest)` (renew DHCP
so DNS is `10.10.50.1`).
