# CGNAT options (reference)

**Your setup:** Dynamic **public** IPv4 — CGNAT is **not active**. **WAN INPUT to Caddy** on janus works. See [vlan-plan.md](../vlan-plan.md).

This page is fallback reference only. CGNAT means no unique public IPv4; inbound port forwarding cannot work. Detect: router WAN IP differs from whatismyip.com, or WAN is `100.64.x.x`.

## Decision tree

1. **ISP offers IPv6 with PD?** → Public ingress over v6 + WireGuard.
2. **Need reliable IPv4 inbound?** → Pay ISP for non-CGNAT address.
3. **Admin only?** → WireGuard-only; skip public Caddy.
4. **Public apps on IPv4, no ISP upgrade?** → Small VPS + frp/rathole or WG site-to-site.
5. **Never** → SaaS tunnel (Cloudflare, ngrok, Tailscale Funnel) as default.

## Options

| Option | Summary |
|--------|---------|
| IPv6 | `AAAA` records; open WAN v6 443/80 only |
| ISP static/non-CGNAT IP | Paid upgrade; simplest IPv4 path |
| WireGuard-only | No public services |
| Reverse tunnel (frp, rathole) | Outbound from LAN to VPS with public IP |
| DDNS alone | **Does not solve CGNAT** — only updates DNS when you have real public IP |

**Avoid:** Cloudflare Tunnel, ngrok, Tailscale Funnel — violate self-hosted preference unless unavoidable.
