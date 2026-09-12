# Runbooks

Short operational procedures. Design lives in the rest of `docs/`.

| Runbook | When |
| ------- | ---- |
| [iot-dns.md](iot-dns.md) | Stage 5 IoT DNS validation; Blocky / intercept regressions |
| [router-restore.md](router-restore.md) | Janus disk loss, nixos-anywhere, or sops key restore |
| [wireguard-clients.md](wireguard-clients.md) | First Pixel / Remorse tunnel configs |
| [wireguard-rotation.md](wireguard-rotation.md) | Stage 6+ server or client WG key rotation |
| [headscale.md](headscale.md) | Stage 6 Headscale user, preauth, client login |
| [acme-failure.md](acme-failure.md) | Lab or public certs fail to issue / renew |
| [capacitor.md](capacitor.md) | `capacitor.lab.zdk.no` 502, Authelia, or Flux OCI |

Do not put secrets in these files. Age key paths and sops *locations* are fine.
