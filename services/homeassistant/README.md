# Home Assistant

Runs in `services/truenas/docker-compose.yml`.

| Hostname | WAN | Auth |
|----------|-----|------|
| `https://ha.lab.zdk.no` | No (split-horizon) | HA-native |
| `https://ha.zdk.no` | Yes | HA-native |

No Authelia — the companion app, webhooks, and APIs would break. Point the
app at **`https://ha.zdk.no`**; Unbound answers that name with Caddy on LAN.

The TrueNAS App listens with **HTTPS** on `10.10.30.20:30103`. Caddy must
`reverse_proxy https://…` with `tls_insecure_skip_verify` (HTTP to that port
is an immediate EOF / 502).

After first-run onboarding, add this to `/mnt/tank/services/homeassistant/config/configuration.yaml` so Caddy on janus (`10.10.30.1`) works:

```yaml
homeassistant:
  external_url: https://ha.zdk.no
  internal_url: https://ha.lab.zdk.no

http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.10.30.1
```

Public DNS: Domeneshop `A` (and `AAAA` if used) for **`ha`**. No public record
for `ha.lab.zdk.no`.

Device IPs: [inventory.md](../../docs/inventory.md). HA initiates to IoT; the router allows `10.10.30.20` → VLAN 40. Prefer static IPs over mDNS.
