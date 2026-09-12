# Caddy ACME (DNS-01) failure

Lab and public names use Let’s Encrypt via Caddy **DNS-01** (Domeneshop
plugin). WAN `:80` is not required. `enableWanCaddy` only opens WAN
`:80`/`:443` for *serving* (Stage 7).

Issuer email: `admin@zdk.no` (`caddyEmail` on janus).

## First checks

```bash
ssh zdk@10.10.20.1
systemctl status caddy --no-pager
journalctl -u caddy -n 80 --no-pager
# look for: obtaining certificate, nameservers, NXDOMAIN, rateLimited
```

Confirm the Domeneshop env is present **without** printing it:

```bash
sudo systemctl show caddy -p EnvironmentFiles
# EnvironmentFile should include the sops template (caddy-domeneshop.env)
```

Caddyfile snippet `dns01` must keep **public** resolvers
(`1.1.1.1` `9.9.9.9`) and `propagation_delay 60s`. Janus Unbound has no
NS for `zdk.no`; certmagic on `127.0.0.53` fails with “could not
determine authoritative nameservers” and browsers see
`tlsv1 alert internal error`.

## Common causes

| Symptom | Fix |
| ------- | --- |
| `could not determine authoritative nameservers` | Resolvers pointed at Unbound. Keep the `dns01` snippet; rebuild if the Caddyfile was edited by hand on the box. |
| `authentication failed` / HTTP 401 from Domeneshop | Rotate `caddy.domeneshopToken` / `Secret` in `secrets/router.yaml`. Same API user as DNSUpdater is fine. Then `nixos-rebuild switch`. |
| Stuck on TXT / timeout after ~60s | Domeneshop lag. Wait and `systemctl restart caddy`. Do not shorten `propagation_delay` below 60s without evidence. |
| sops / empty env | Restore janus `/var/lib/sops-nix/key.txt` ([router-restore.md](router-restore.md)). |
| Rate limited | Wait out Let’s Encrypt. Do not hammer `restart`. Staging is not wired; do not invent a second issuer in the Caddyfile. |
| `lab.zdk.no` SERVFAIL in Unbound | Unrelated to issuance. Browsing uses Unbound `local-data`; ACME does not. |

## What you should see when it works

- `*.lab.zdk.no` has **no** public A/AAAA. Issuance still succeeds (DNS-01).
- Caddy `lab_only` aborts non-`10.10.0.0/16` clients on lab Host headers.
  That is not an ACME failure.
- Public names (`img.zdk.no`, `ha.zdk.no`) can have certs **before**
  `enableWanCaddy`. They just are not reachable from WAN yet.

## Manual poke (trusted)

```bash
curl -sI https://auth.lab.zdk.no | head -n 15
echo | openssl s_client -connect 10.10.30.1:443 -servername grafana.lab.zdk.no 2>/dev/null | openssl x509 -noout -issuer -dates -ext subjectAltName
```

Expect Let’s Encrypt, not a Caddy default / internal cert.

## Do not

- Point ACME at `127.0.0.53` or `10.10.30.1`.
- Open WAN `:80` “for HTTP-01”. This lab is DNS-01.
- Put Domeneshop tokens in the Caddyfile or in git plaintext.
