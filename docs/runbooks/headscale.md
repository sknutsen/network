# Headscale

Control plane for Tailscale clients. Classic `wg0` stays the remote-access
VPN. Headscale does **not** replace Pixel/Remorse WireGuard.

Listen: **`127.0.0.1:8081`**. UniFi Inform owns `:8080`. UniFi STUN owns
**`3478/udp`** — do not enable embedded Headscale DERP on that port.
Caddy: `https://headscale.lab.zdk.no` (no Authelia, `lab_only`).

Login-server is reachable from trusted / servers / classic WG
(`10.10.0.0/16`). Not from WAN. Pixel on LTE must use `wg0` first.

## After janus rebuild

```bash
ssh zdk@10.10.20.1
sudo systemctl is-active headscale
sudo ss -lntp | grep 8081
curl -sI https://headscale.lab.zdk.no | head
```

Expect `active`, `127.0.0.1:8081`, HTTP 200 (or a Headscale page). Cert
is DNS-01; first hit can take a minute.

Do **not** bind Headscale to `:8080` or `:11443`.

## User and preauth key

On janus:

```bash
sudo headscale users create zdk
sudo headscale users list   # note the numeric ID
sudo headscale preauthkeys create --user <USER_ID> --reusable --expiration 24h
```

`--user` is the numeric ID from `users list`, not the name (Headscale
0.29). The key is a secret. Reusable + 24h is enough for Pixel and
Remorse on the same day.

## Clients

Login-server: `https://headscale.lab.zdk.no`

**Remorse (on Hai-Fi, tunnel off):**

```bash
tailscale up --login-server https://headscale.lab.zdk.no --authkey <key>
```

Or Tailscale.app → Settings → Accounts → Use an alternate coordination
server.

**Pixel:** turn classic WireGuard **on** (LTE or Hai-Fi). In Tailscale,
same custom server + auth key. Keep `wg0` for `10.10.0.0/16`. Headscale
addresses are `100.64.0.0/10` and MagicDNS `*.ts.zdk.no`.

```bash
sudo headscale nodes list
```

Expect both nodes, same user. `ping` the `100.64.` address of the other
node.

## What this pass does not do

- Subnet router on janus (`--advertise-routes=10.10.0.0/16`). Lab HTTP
  still goes over classic `wg0` or the LAN.
- Embedded DERP (UniFi STUN `:3478`). LTE mesh may use Tailscale’s public
  DERP map if holepunch fails.
- OIDC via Authelia. Preauth keys only.
- Noise key in sops. Headscale writes `/var/lib/headscale/noise_private.key`
  on first start.

## Rotate a preauth key

```bash
sudo headscale preauthkeys list
sudo headscale preauthkeys expire --id <KEY_ID>
sudo headscale preauthkeys create --user <USER_ID> --reusable --expiration 24h
```

Already-joined nodes keep working. Only new joins need a live key.
