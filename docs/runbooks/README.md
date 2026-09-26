# Runbooks

Short operational procedures. Design lives in the rest of `docs/`.

| Runbook | When |
| ------- | ---- |
| [iot-dns.md](iot-dns.md) | IoT DNS / Blocky regressions |
| [router-restore.md](router-restore.md) | Janus disk loss, nixos-anywhere, or sops key restore |
| [wireguard-clients.md](wireguard-clients.md) | Pixel / Remorse tunnel configs |
| [wireguard-rotation.md](wireguard-rotation.md) | Server or client WG key rotation |
| [headscale.md](headscale.md) | Headscale user, preauth, client login |
| [wan-caddy.md](wan-caddy.md) | WAN 80/443, img/ha/code, DNSUpdater |
| [acme-failure.md](acme-failure.md) | Lab or public certs fail to issue / renew |
| [capacitor.md](capacitor.md) | `capacitor.lab.zdk.no` 502, Authelia, or Flux OCI |
| [network-monitoring.md](network-monitoring.md) | unpoller user, CRS310 SNMP, Grafana Network / Alertmanager |

Do not put secrets in these files. Age key paths and sops *locations* are fine.
