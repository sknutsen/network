# IoT DNS validation

Confirms Blocky is the only resolver IoT can use. Policy:
[firewall-matrix.md](../firewall-matrix.md) rules 5–6b. Flag:
`homelab.router.enableBlocky` on janus.

This cannot be finished from Remorse or janus. Packets must ingress `vlan40`.

## Already true on janus (2026-09-12)

| Check | Live value |
| ----- | ---------- |
| IoT DHCP DNS | `10.10.30.21` |
| IoT domain-search | omitted (no option 119; `domain=` not scoped to `10.10.40.0/24`) |
| IoT pool lease | `1h` (`10.10.40.100–250`) |
| DNAT | `vlan40` `:53`/`:853` → `10.10.30.21` (no SNAT) |
| Unbound on `10.10.40.1` | not listening (`enableBlocky`) |
| IoT INPUT `:53`/`:853` | drop (backup if DNAT misses) |
| Blocky (from janus) | `example.com` answers; `grafana.lab.zdk.no` **NXDOMAIN** |

Reservations (Hue, TV, …) keep `infinite` leases. That is expected.

## Client

Join SSID **`Hai-Fi Wai-Fi (IoT)`**.

Do **not** use Remorse, Pingu, or Pixel 7 with their usual MACs. Those
`dhcp-host` rows pin `10.10.20.x` on every VLAN. On IoT that is a broken
address.

Use a **randomized / private Wi-Fi MAC** (or any device that is not in
`router/modules/dhcp.nix`). You should get `10.10.40.100–250`.

Need a shell: Termux, a spare laptop, or `dig` from a Linux VM. A TV that
only “has internet” is not this check.

## Checks (from the IoT client)

```bash
# 1. DHCP handed out Blocky, not 10.10.40.1
#    Skip resolvectl unless systemd-resolved is running.
#    Android/Termux:  getprop net.dns1 ; getprop net.dns2
#    Linux:           cat /etc/resolv.conf   (and the lease, see below)
#    macOS:           ipconfig getpacket en0
#    Expect nameserver 10.10.30.21. No search lab.zdk.no.
#    nameserver 10.10.40.1 + search lab.zdk.no was the pre-fix offer:
#    global domain= sent option 15 to every VLAN, and clients that omit
#    option 6 from the PRL write the gateway. After janus rebuild + renew:
#    10.10.30.21 and no search. Intercept still works either way.
#    Android Private DNS / DoH is not this check (not interceptable).

# 2. Intercept — client still thinks it spoke to 8.8.8.8
dig @8.8.8.8 example.com A +short
# Expect an A record. Timeout = DNAT or Blocky down.

# 3. Lab names stay hidden
dig @8.8.8.8 grafana.lab.zdk.no A
# Expect NXDOMAIN (Blocky denylist). An A record is a fail.

# 4. Gateway dest is also intercepted (not Unbound)
#    DNAT rewrites every vlan40 :53 to Blocky, including 10.10.40.1.
#    Conntrack makes the reply look like it came from 10.10.40.1.
#    Timeout would mean DNAT missed and INPUT drop ate the packet.
dig @10.10.40.1 example.com A +short
# Expect an A record (Blocky). Then the real bypass check:
dig @10.10.40.1 grafana.lab.zdk.no A
# Expect NXDOMAIN. An A record means Unbound answered — fail.
```

Optional, same client:

```bash
dig @10.10.30.21 example.com A +short    # direct Blocky (forward allow)
dig @1.1.1.1 example.com A +short        # also intercepted
```

DoH (`:443`) is **not** redirected. A device that only uses DoH can skip
Blocky. That is accepted for v1.

## Pass / fail

Validated 2026-09-12 from Socrates on `Hai-Fi Wai-Fi (IoT)`. Repeat after
dnsmasq or nftables changes.

| Symptom | Likely cause |
| ------- | ------------ |
| DNS is `10.10.40.1` | Client has a stale lease; wait ≤ 1 h or forget the network. `enableBlocky` off. |
| Address is `10.10.20.x` on IoT SSID | MAC reservation for trusted. Randomize the MAC. |
| `@8.8.8.8` times out | Blocky down, TrueNAS default gw not `10.10.30.1`, or nft DNAT missing. |
| `@8.8.8.8` returns `grafana.lab.zdk.no` | Query never hit Blocky (not on VLAN 40, or DoH). |
| `@10.10.40.1 example.com` times out | DNAT missed and INPUT drop ate it. Check `nft list chain ip nat prerouting`. |
| `@10.10.40.1 grafana.lab.zdk.no` is an A | Unbound answered (bypass). Confirm `enableBlocky` and that Unbound is not on `.40.1`. |

## Janus-side (no client)

```bash
ssh zdk@10.10.20.1
sed -n '/VLAN 40/,/VLAN 50/p' /etc/dnsmasq-homelab.conf
sudo nft list chain ip nat prerouting
dig @10.10.30.21 grafana.lab.zdk.no A   # NXDOMAIN
ss -ulnp | grep ':53'                   # no 10.10.40.1
```
