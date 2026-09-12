# Network monitoring

Bring up unpoller, CRS310 SNMP, and the Grafana Network dashboard.

Design: [architecture.md § Monitoring](../architecture.md#monitoring-and-logging).
Dashboard JSON: `k8s/clusters/homelab/infra/core/dashboards/network-overview.json`.
Alerts: `k8s/clusters/homelab/infra/core/network-alerts.yaml`.

## 1. UniFi user for unpoller

Create a **local** UniFi OS Server user (not SSO):

- Username: `unpoller`
- Role: view-only / read-only on the Network application (all sites)
- Password: the value in sops `unpoller/password`

```bash
sops -d --extract '["unpoller"]["password"]' secrets/router.yaml
```

Do not reuse the admin account. unpoller on janus talks to
`https://127.0.0.1:11443` (self-signed, verify off).

## 2. CRS310 SNMP

Copy `switch/crs310.rsc` to the switch and `/import` it. That enables SNMPv2c
community `zdk-crs310-ro` from **`10.10.10.1` only**.

From janus after rebuild:

## 3. Rebuild janus

Trusted VLAN or on-box:

```bash
nixos-rebuild switch --flake '.#optiplex' --target-host root@10.10.20.1
```

Confirm:

```bash
curl -sf http://10.10.30.1:9101/metrics | head
curl -sf http://10.10.30.1:9130/metrics | head
curl -sf 'http://10.10.30.1:9116/snmp?module=if_mib&auth=crs310&target=10.10.10.2' | head
```

unpoller `/metrics` stays thin until the UniFi user exists (then
`unpoller_device_*` appears). `UnpollerDown` waits 15 minutes before firing.

## 4. Flux

Push this tree so kube-prometheus-stack picks up scrape jobs, the dashboard,
`network-alerts`, and `alertmanager.lab.zdk.no`.

## UIs

| URL | Auth |
|-----|------|
| https://grafana.lab.zdk.no | Authelia → folder **Network** |
| https://alertmanager.lab.zdk.no | Authelia |
| https://unifi.lab.zdk.no | UniFi-native |

Unknown-MAC alerts ignore the guest VLAN and wait 30 minutes (phone MAC
randomization). Inventory-offline stays a dashboard table only — sleeping
laptops are not an alert.

Socrates, Peon, and the Nintendo Switch still have no MACs in
`constants.nix`. Add them when those devices are on the LAN.
