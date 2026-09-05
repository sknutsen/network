# Device inventory

VLAN assignments, static IPs, switch ports, and dnsmasq reservations. Network
design: [vlan-plan.md](vlan-plan.md).

## Servers (VLAN 30)

| Name        | Hardware        | OS            | Static IP                                                                                 | Connection                                    | Role                                                                                                                                |
| ----------- | --------------- | ------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **TrueNAS** | NAS             | TrueNAS SCALE | `10.10.30.20` (+ `.21` alias for Blocky); MAC `cc:28:aa:42:c2:9d`                         | Wired (port 4)                                | HA, Immich, Authelia, Forgejo (TrueNAS Apps); Blocky; **UI:** `https://truenas.lab.zdk.no` (Caddy), not direct IP from trusted/mgmt |
| **nordri**  | RK1 (Turing Pi) | NixOS + k3s   | `10.10.30.11`                                                                             | Wired (port 3); board MAC `d0:ea:11:6d:36:a7` | k3s control plane                                                                                                                   |
| **sudri**   | RK1 (Turing Pi) | NixOS + k3s   | `10.10.30.12`                                                                             | Wired (port 3); board MAC `d0:ea:11:6d:36:a7` | k3s worker                                                                                                                          |
| **austri**  | RK1 (Turing Pi) | NixOS + k3s   | `10.10.30.13`                                                                             | Wired (port 3); board MAC `d0:ea:11:6d:36:a7` | k3s worker                                                                                                                          |
| **vestri**  | RK1 (Turing Pi) | NixOS + k3s   | `10.10.30.14`                                                                             | Wired (port 3); board MAC `d0:ea:11:6d:36:a7` | k3s worker                                                                                                                          |
| **Zpi**     | Raspberry Pi 5  | Raspbian      | `10.10.30.15`; MAC `d8:3a:dd:cf:e1:75` (eth), `d8:3a:dd:cf:e1:78` (Wi-Fi, no reservation) | Not on CRS310                                 | Audio casting to speaker system                                                                                                     |

**Turing Pi nodes ethernet:** one 2.5GbE on CRS310 port 3 (`d0:ea:11:6d:36:a7`).
Not reserved — the four RK1s use `.11`–`.14` with their own MACs once they boot.

**Turing Pi BMC:** CRS310 port 5 → **VLAN 10 (mgmt)** only. MAC
`d0:ea:11:6d:36:a9` → `10.10.10.5` (`turing-bmc.lab.zdk.no`).

## Infrastructure (mgmt / L2)

| Name              | Hardware                        | MAC                                                                                  | Connection                                 | Notes                                                                                              |
| ----------------- | ------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| **janus**         | Dell OptiPlex 9020 MT + i350-T2 | `wan0` `34:17:eb:96:84:20`; `lan0` `a0:36:9f:33:ae:96`; `spare0` `a0:36:9f:33:ae:97` | I217LM → WAN; i350 port 1 → CRS310 trunk   | `janus.lab.zdk.no` → `10.10.30.1`; NixOS + **UniFi OS Server (functional)** + Headscale (`:8081`)  |
| **CRS310**        | MikroTik CRS310-8G+2S+IN        | —                                                                                    | Router trunk on port 1; mgmt `10.10.10.2`  | **Acquired**; L2 only — [switch/crs310.rsc](../switch/crs310.rsc); no PoE — AP uses owned injector |
| **USW-NC**        | UniFi Flex Mini                 | `f4:e2:c6:55:40:ab`                                                                  | CRS310 ether6 ↔ port 4; mgmt `10.10.10.3`  | Network closet. Trunk native 10 + tagged 20/40. Port 2 → USW-LR; port 5 → SW-O                     |
| **USW-LR**        | UniFi Flex Mini                 | `d0:21:f9:b2:bf:5d`                                                                  | USW-NC port 2 ↔ port 1; mgmt `10.10.10.4`  | Living room. Trunk native 10 + tagged 40; access 40 for Hue/Trådfri                                |
| **SW-O**          | Unmanaged switch                | —                                                                                    | USW-NC port 5                              | Office. All ports VLAN 20 (pingu, Peon). No tagging                                                |
| **Turing Pi BMC** | Turing Pi 2.5 BMC               | `d0:ea:11:6d:36:a9`                                                                  | CRS310 port 5 (access 10); `10.10.10.5`    | VLAN 10 only; `turing-bmc.lab.zdk.no`                                                              |
| **U7 Lite**       | Ubiquiti UniFi AP (WiFi 7)      | `a8:9c:6c:b8:f6:27`                                                                  | CRS310 port 2 (trunk) + owned PoE injector | **Acquired**; SSIDs → VLANs 20/40/50 via UniFi OS Server on router; no reserved IP (VLAN 10 DHCP)  |

## Trusted (VLAN 20) — SSID `Hai-Fi Wai-Fi`

| Name         | Hardware         | OS      | Static IP     | MAC                                                          | Connection                           |
| ------------ | ---------------- | ------- | ------------- | ------------------------------------------------------------ | ------------------------------------ |
| **Pingu**    | Desktop / gaming | NixOS   | `10.10.20.10` | `f0:2f:74:dd:e6:48`                                          | Wired (SW-O → USW-NC port 5)         |
| **Socrates** | ThinkPad         | NixOS   | `10.10.20.11` | —                                                            | WiFi `Hai-Fi Wai-Fi` or docked       |
| **Remorse**  | MacBook Air      | macOS   | `10.10.20.12` | `96:5b:ef:ae:02:04` (Wi-Fi)                                  | WiFi `Hai-Fi Wai-Fi`                 |
| **Peon**     | Work laptop      | Windows | `10.10.20.13` | —                                                            | Wired (SW-O) or WiFi `Hai-Fi Wai-Fi` |
| **Pixel 7**  | Phone            | Android | `10.10.20.14` | `ee:15:ec:33:4e:84` (Wi-Fi 1); `76:37:82:bf:88:3d` (Wi-Fi 2) | WiFi `Hai-Fi Wai-Fi`                 |

**Peon:** Trusted for now — isolate later if work policy requires.

## IoT (VLAN 40) — SSID `Hai-Fi Wai-Fi (IoT)` + wired hubs

Only devices needing **direct IP reachability** get reservations. Hub-managed
bulbs/sensors do not need IPs.

| Name                | Hardware          | Static IP     | MAC                 | Connection                 | Notes                                  |
| ------------------- | ----------------- | ------------- | ------------------- | -------------------------- | -------------------------------------- |
| **Samsung TV**      | Smart TV (Tizen)  | `10.10.40.10` | `bc:45:5b:92:63:70` | WiFi `Hai-Fi Wai-Fi (IoT)` | HA; casting target                     |
| **Rusken**          | Roborock vacuum   | `10.10.40.11` | `b0:4a:39:a2:e9:20` | WiFi `Hai-Fi Wai-Fi (IoT)` | HA                                     |
| **Philips Hue hub** | Hue Bridge        | `10.10.40.12` | `ec:b5:fa:12:d3:7c` | Wired (USW-LR, access 40)  | HA → hub; bulbs via Zigbee             |
| **IKEA Trådfri**    | Dirigera/Gateway  | `10.10.40.13` | `68:ec:8a:02:69:43` | Wired (USW-LR, access 40)  | HA → hub; bulbs via Zigbee/Thread      |
| **Nintendo Switch** | Console           | `10.10.40.14` | —                   | WiFi `Hai-Fi Wai-Fi (IoT)` | Online gaming; local LAN play deferred |
| **Samsung Odyssey** | Smart Monitor     | `10.10.40.15` | `e8:aa:cb:df:cb:1e` | WiFi `Hai-Fi Wai-Fi (IoT)` | HA; casting target                     |
| **Chromecast**      | Google Chromecast | `10.10.40.16` | `f4:f5:d8:5f:f1:7a` (Wi-Fi); `44:09:b8:01:80:87` (eth) | Wi-Fi `Hai-Fi Wai-Fi (IoT)` or wired (USW-LR, access 40) | Casting from trusted                   |

**Hue + Trådfri hubs + Chromecast (eth):** Wired on USW-LR (access VLAN 40).

## Guest (VLAN 50) — SSID `Hai-Fi Wai-Fi (Guest)`

No reservations. Client isolation ON. DHCP DNS is public resolvers (1.1.1.1 /
9.9.9.9).

## Home Assistant integrations

All use **servers → IoT ALLOW** from `10.10.30.20`:

| Integration       | Target IP     |
| ----------------- | ------------- |
| Samsung TV        | `10.10.40.10` |
| Roborock (Rusken) | `10.10.40.11` |
| Philips Hue hub   | `10.10.40.12` |
| IKEA Trådfri hub  | `10.10.40.13` |
| Samsung Odyssey   | `10.10.40.15` |
| Chromecast        | `10.10.40.16` |

## dnsmasq static reservations

DHCP `dhcp-host` rows live in `router/modules/dhcp.nix` (MACs in
`router/lib/constants.nix`). Unbound A records are independent of DHCP.

| Hostname                    | IP            | VLAN                                   | MAC (dnsmasq)                                                     |
| --------------------------- | ------------- | -------------------------------------- | ----------------------------------------------------------------- |
| `janus.lab.zdk.no`          | `10.10.30.1`  | 30 (servers GW; Unbound)               | — (router)                                                        |
| `truenas.lab.zdk.no`        | `10.10.30.1`  | 30 (Caddy → NAS `:443`; host is `.20`) | `cc:28:aa:42:c2:9d` → `.20`                                       |
| `auth.lab.zdk.no`           | `10.10.30.1`  | 30 (Caddy → Authelia App `:9091`)      | —                                                                 |
| `blocky.lab.zdk.no`         | `10.10.30.21` | 30                                     | — (alias on TrueNAS)                                              |
| `headscale.lab.zdk.no`      | `10.10.30.1`  | 30 (Caddy → `127.0.0.1:8081`)          | —                                                                 |
| `crs310.lab.zdk.no`         | `10.10.10.2`  | 10                                     | — (static on switch)                                              |
| `usw-nc.lab.zdk.no`         | `10.10.10.3`  | 10                                     | `f4:e2:c6:55:40:ab`                                               |
| `usw-lr.lab.zdk.no`         | `10.10.10.4`  | 10                                     | `d0:21:f9:b2:bf:5d`                                               |
| `turing-bmc.lab.zdk.no`     | `10.10.10.5`  | 10                                     | `d0:ea:11:6d:36:a9`                                               |
| `nordri.lab.zdk.no`         | `10.10.30.11` | 30                                     | — (board uplink `d0:ea:11:6d:36:a7`, not reserved)                |
| `sudri.lab.zdk.no`          | `10.10.30.12` | 30                                     | — (same board uplink)                                             |
| `austri.lab.zdk.no`         | `10.10.30.13` | 30                                     | — (same board uplink)                                             |
| `vestri.lab.zdk.no`         | `10.10.30.14` | 30                                     | — (same board uplink)                                             |
| `zpi.lab.zdk.no`            | `10.10.30.15` | 30                                     | `d8:3a:dd:cf:e1:75` (eth); Wi-Fi `d8:3a:dd:cf:e1:78` not reserved |
| `pingu.lab.zdk.no`          | `10.10.20.10` | 20                                     | `f0:2f:74:dd:e6:48`                                               |
| `socrates.lab.zdk.no`       | `10.10.20.11` | 20                                     | —                                                                 |
| `remorse.lab.zdk.no`        | `10.10.20.12` | 20                                     | `96:5b:ef:ae:02:04`                                               |
| `peon.lab.zdk.no`           | `10.10.20.13` | 20                                     | —                                                                 |
| `pixel7.lab.zdk.no`         | `10.10.20.14` | 20                                     | `ee:15:ec:33:4e:84`, `76:37:82:bf:88:3d`                          |
| `samsung-tv.iot.lab.zdk.no` | `10.10.40.10` | 40                                     | `bc:45:5b:92:63:70`                                               |
| `rusken.iot.lab.zdk.no`     | `10.10.40.11` | 40                                     | `b0:4a:39:a2:e9:20`                                               |
| `hue.iot.lab.zdk.no`        | `10.10.40.12` | 40                                     | `ec:b5:fa:12:d3:7c`                                               |
| `tradfri.iot.lab.zdk.no`    | `10.10.40.13` | 40                                     | `68:ec:8a:02:69:43`                                               |
| `switch.iot.lab.zdk.no`     | `10.10.40.14` | 40                                     | —                                                                 |
| `odyssey.iot.lab.zdk.no`    | `10.10.40.15` | 40                                     | `e8:aa:cb:df:cb:1e`                                               |
| `chromecast.iot.lab.zdk.no` | `10.10.40.16` | 40                                     | `f4:f5:d8:5f:f1:7a` (Wi-Fi), `44:09:b8:01:80:87` (eth)            |

U7 Lite (`a8:9c:6c:b8:f6:27`) is on VLAN 10 DHCP — no reserved IP.

Still unknown: per-RK1 NICs (nordri–vestri), Socrates, Peon, Nintendo Switch.

## VLAN assignment rationale

| Zone           | Devices                                 | Policy                           |
| -------------- | --------------------------------------- | -------------------------------- |
| **30 servers** | TrueNAS, nordri–vestri (Turing Pi), Zpi | Trusted + VPN; HA → IoT outbound |
| **20 trusted** | Laptops, desktop, phone                 | Reach servers + internet         |
| **40 iot**     | TV, hubs, cast targets, Switch          | Internet + HA from servers only  |

**Zpi:** Servers VLAN for audio casting; move to trusted if it becomes a daily
driver.

**Nintendo Switch:** IoT zone; local multiplayer rules deferred — see
[firewall-matrix.md](firewall-matrix.md).
