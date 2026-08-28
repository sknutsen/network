# Home Assistant

Runs in `services/truenas/docker-compose.yml`. UI: `https://ha.lab.zdk.no` (Authelia).

After first-run onboarding, add this to `/mnt/tank/services/homeassistant/config/configuration.yaml` so Caddy on janus (`10.10.30.1`) works:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.10.30.1
```

Device IPs: [inventory.md](../../docs/inventory.md). HA initiates to IoT; the router allows `10.10.30.20` → VLAN 40. Prefer static IPs over mDNS.
