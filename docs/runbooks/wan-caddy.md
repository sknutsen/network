# WAN Caddy (Stage 7)

`enableWanCaddy` opens WAN **80/443** to Caddy on janus. Certs are already
DNS-01. Hairpin NAT is **off** — do not test the public names via the WAN
IP from inside the lab.

Public: `img.zdk.no` (Immich), `ha.zdk.no` (HA). `code.zdk.no` / `zdk.no`
stay commented. `*.lab.zdk.no` has no public `A`/`AAAA`; `lab_only` aborts
WAN clients that guess the Host header.

## After janus rebuild

From Remorse (split-horizon → `10.10.30.1`, not a WAN test):

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://ha.zdk.no
curl -sS -o /dev/null -w '%{http_code}\n' https://img.zdk.no
ssh zdk@10.10.20.1 'sudo nft list chain inet filter input | grep -A2 wan_https4'
```

Expect HTTP 200 and the `wan_https4` meter.

## WAN test (Pixel LTE, classic WG **off**)

Carrier DNS must answer `84.48.97.100`. Tailscale can stay up.

```bash
# on the phone, or from any off-lab host
curl -sSI https://ha.zdk.no | head
curl -sSI https://img.zdk.no | head
# lab Host on the WAN IP must fail
curl -sSI --resolve ha.lab.zdk.no:443:84.48.97.100 https://ha.lab.zdk.no | head
```

Expect 200 on the public names. Lab Host should be empty / connection
reset (`lab_only` abort), not an Authelia or HA page.

## Home Assistant

`/mnt/tank/services/homeassistant/config/configuration.yaml`:

```yaml
homeassistant:
  external_url: https://ha.zdk.no
  internal_url: https://ha.lab.zdk.no

http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.10.30.1
```

Restart the HA TrueNAS App after editing. Companion app URL:
`https://ha.zdk.no`.

## Immich

Admin → Settings → Server: external domain `https://img.zdk.no`. Mobile
app uses that URL at home and away (Unbound splits `img.zdk.no` to Caddy).

## Do not

- Publish `A`/`AAAA` for `*.lab.zdk.no`
- Uncomment `code.zdk.no` / `zdk.no` in the Caddyfile
- Open WAN SSH
- Enable hairpin NAT to test from Remorse

## SSL Labs (2026-09-12)

Unpublished API scan of `84.48.97.100`:

| Host | Grade |
| ---- | ----- |
| `img.zdk.no` | **A** |
| `ha.zdk.no` | **A** |

TLS 1.2 + 1.3, forward secrecy, no Heartbleed/FREAK/POODLE. No HSTS — that is
the usual gap to A+. Caddy default. Do not publish lab names.
