# Home Assistant

Live deploy is a **TrueNAS App** on `10.10.30.20:30103`. Do not also start
the Home Assistant service in `services/truenas/docker-compose.yml`.

| Hostname | WAN | Who | Auth |
|----------|-----|-----|------|
| `https://ha.lab.zdk.no` | No (split-horizon) | Trusted, VPN, IoT | HA-native |
| `https://ha.zdk.no` | Yes | Internet + same LAN clients | HA-native |

No Authelia — the companion app, webhooks, and APIs would break. Point the
app at **`https://ha.zdk.no`**; Unbound (and Blocky on IoT) answers that
name with Caddy on LAN.

The TrueNAS App listens with **HTTPS** on `10.10.30.20:30103`. Caddy must
`reverse_proxy https://…` with `tls_insecure_skip_verify` (HTTP to that port
is an immediate EOF / 502). nftables drops forwarded `:30103`.

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

## Matter (Dirigera / IoT)

Do **not** move HA onto the IoT VLAN. Sharing IKEA devices already on
Trådfri/Dirigera is multi-admin, not “put the UI next to the bulbs.”

| Path | Why |
|------|-----|
| IoT → TrueNAS **UDP/TCP 5540** (v4) and VLAN 30 ULA **5540** (v6) + ICMPv6 | Devices and the Matter controller talk here. HTTPS is the wrong port. |
| Avahi **vlan30 ↔ vlan40** | `_matter._tcp` / `_matterc._udp` across the router |
| IoT → Caddy `:443` for `ha.lab` / `ha.zdk` | Companion app if the phone joins IoT Wi-Fi. Not Immich/Forgejo. |

IKEA share flow (preferred): phone stays on **trusted**. Home Smart talks
to Dirigera (`10.10.40.13`, already allowed). HA UI stays on trusted.
Enter the sharing code in HA. The new fabric session is Matter `:5540`,
not the HA web UI.

On the TrueNAS App, the Python Matter Server must be reachable on the
host — **host network** or publish `5540/udp` and `5540/tcp`, and give
the TrueNAS NIC a VLAN 30 ULA (RA from janus is `fd10:10:10:30::/64`).
`:5580` (Matter Server WebSocket) stays on the compose/app network; do
not publish it to IoT.
