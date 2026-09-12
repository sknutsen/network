# WireGuard clients

Classic `wg0` on janus. Headscale is not this path. Private keys stay off
git (`/tmp/pixel-wg.key`, `/tmp/remorse-wg.key`).

| Peer | Address | Device |
| ---- | ------- | ------ |
| janus | `10.10.255.1/24` | server (`Co1PKt82qJUOXLsLRvi4+Ml7ZGJwodjb1JHPZ8ibrCA=`) |
| pixel | `10.10.255.2/32` | phone |
| remorse | `10.10.255.3/32` | this Mac, when away |

Split-tunnel: `AllowedIPs = 10.10.0.0/16`. DNS is Unbound on `10.10.255.1`.
SSH to janus from a WG address is **denied**. `Endpoint` is `vpn.zdk.no`
(DNSUpdater keeps the Domeneshop `A` on the current WAN IPv4).

Pixel validated 2026-09-12 from LTE: handshake, Grafana/Authelia, split-tunnel, SSH denied. Remorse has no handshake yet — leave the Mac tunnel off on Hai-Fi; confirm from off-lab.

## Pixel (`wg0.conf` or the WireGuard app)

```ini
[Interface]
PrivateKey = <contents of /tmp/pixel-wg.key>
Address = 10.10.255.2/32
DNS = 10.10.255.1

[Peer]
PublicKey = Co1PKt82qJUOXLsLRvi4+Ml7ZGJwodjb1JHPZ8ibrCA=
Endpoint = vpn.zdk.no:51820
AllowedIPs = 10.10.0.0/16
PersistentKeepalive = 25
```

## Remorse (away)

```ini
[Interface]
PrivateKey = <contents of /tmp/remorse-wg.key>
Address = 10.10.255.3/32
DNS = 10.10.255.1

[Peer]
PublicKey = Co1PKt82qJUOXLsLRvi4+Ml7ZGJwodjb1JHPZ8ibrCA=
Endpoint = vpn.zdk.no:51820
AllowedIPs = 10.10.0.0/16
PersistentKeepalive = 25
```

On macOS: WireGuard app → Add tunnel from file, or `wg-quick up`.

## After janus rebuild

```bash
ssh zdk@10.10.20.1 'sudo wg show'
# from the client (LTE / off-lab):
ping -c 2 10.10.255.1
dig @10.10.255.1 grafana.lab.zdk.no A +short
curl -sI https://auth.lab.zdk.no | head
```

Expect handshake on janus, A record `10.10.30.1`, Authelia. `ssh zdk@10.10.20.1`
from the tunnel must fail.
