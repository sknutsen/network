# WireGuard key rotation

`enableWireGuard` is **true**. Headscale is not deployed yet. Peers:
Pixel `10.10.255.2`, Remorse `10.10.255.3`. Client files:
[wireguard-clients.md](wireguard-clients.md).

Listen port: **`51820/udp`** on WAN. Headscale (when added) is
**`127.0.0.1:8081`** — UniFi Inform owns `:8080`. Caddy
`headscale.lab.zdk.no` has no Authelia.

SSH is still trusted-VLAN only in v1. Rotate from Remorse / Pingu, not
through a WG session you are about to kill.

## Layout (intended)

| Item | Where |
| ---- | ----- |
| Server private key | sops `wireguard/serverPrivateKey` → `/run/secrets/wireguard/serverPrivateKey` |
| Server listen | janus `wg0` `10.10.255.1/24` |
| Client peers | `networking.wireguard.interfaces.wg0.peers` in `vpn.nix` |
| Headscale | janus loopback `:8081`; login-server URL via Caddy |

Recipients for `secrets/router.yaml` are janus + pingu + remorse.

## Rotate the server key

1. Generate a new keypair off-box (`wg genkey` / `wg pubkey`). Do not
   commit the private key in plaintext.
2. `sops secrets/router.yaml` and replace `wireguard.serverPrivateKey`.
3. Put the **new** server public key on every client (phone, laptop,
   Headscale node if it has a WG peer).
4. `nixos-rebuild switch` janus (see [router-restore.md](router-restore.md)).
5. Bring each client up. Confirm `wg show` on janus: handshake, then
   `10.10.255.0/24` → servers / mgmt / Caddy. SSH to janus from a WG
   address is **denied** (v1).

If you lose the server private key, treat it as a rotate: new key, update
sops, update all clients. The old key cannot be recovered from the
ciphertext without an age identity.

## Rotate one client

1. New client keypair.
2. Replace that peer’s `publicKey` (and `allowedIPs` if the address
   changes) in `vpn.nix`.
3. Rebuild janus, then install the new private key only on that device.
4. Leave other peers alone.

## After Headscale is live, add here

- Headscale preauth-key rotation (namespace, expiry, revoke).
