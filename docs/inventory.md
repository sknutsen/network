# Device inventory

VLAN assignments, static IPs, switch ports, and dnsmasq reservations. Network design: [vlan-plan.md](vlan-plan.md).

## Servers (VLAN 30)

| Name | Hardware | OS | Static IP | Connection | Role |
|------|----------|-----|-----------|------------|------|
| **TrueNAS** | NAS | TrueNAS SCALE | `10.10.30.20` (+ `.21` alias for Blocky) | Wired (port 4) | HA, Forgejo, Authelia, Blocky |
| **nordri** | RK1 (Turing Pi) | NixOS + k3s | `10.10.30.11` | Wired (port 3) | k3s control plane |
| **sudri** | RK1 (Turing Pi) | NixOS + k3s | `10.10.30.12` | Wired (port 3) | k3s worker |
| **austri** | RK1 (Turing Pi) | NixOS + k3s | `10.10.30.13` | Wired (port 3) | k3s worker |
| **vestri** | RK1 (Turing Pi) | NixOS + k3s | `10.10.30.14` | Wired (port 3) | k3s worker |
| **Zpi** | Raspberry Pi 5 | Raspbian | `10.10.30.15` | Wired (port 5) | Audio casting to speaker system |

**Turing Pi BMC:** separate Ethernet → **VLAN 10 (mgmt)** only. No static IP until the MAC is known (DHCP pool `.100–.200`).

## Infrastructure (mgmt / L2)

| Name | Hardware | Connection | Notes |
|------|----------|------------|-------|
| **janus** | Dell OptiPlex 9020 MT + i350-T2 | I217LM → WAN; i350 port 1 → CRS310 trunk | `janus.lab.zdk.no` → `10.10.30.1`; NixOS + **UniFi OS Server (functional)** + Headscale (`:8081`) |
| **CRS310** | MikroTik CRS310-8G+2S+IN | Router trunk on port 1; mgmt `10.10.10.2` | **Acquired**; L2 only — [switch/crs310.rsc](../switch/crs310.rsc); no PoE — AP uses owned injector |
| **U7 Lite** | Ubiquiti UniFi AP (WiFi 7) | CRS310 port 2 (trunk) + owned PoE injector | **Acquired**; SSIDs → VLANs 20/40/50 via UniFi OS Server on router |

## Trusted (VLAN 20) — SSID `Hai-Fi Wai-Fi`

| Name | Hardware | OS | Static IP | Connection |
|------|----------|-----|-----------|------------|
| **Pingu** | Desktop / gaming | NixOS | `10.10.20.10` | Wired (port 6, 2.5G) |
| **Socrates** | ThinkPad | NixOS | `10.10.20.11` | WiFi `Hai-Fi Wai-Fi` or docked |
| **Remorse** | MacBook Air | macOS | `10.10.20.12` | WiFi `Hai-Fi Wai-Fi` |
| **Peon** | Work laptop | Windows | `10.10.20.13` | WiFi `Hai-Fi Wai-Fi` |
| **Pixel 7** | Phone | Android | `10.10.20.14` | WiFi `Hai-Fi Wai-Fi` |

**Peon:** Trusted for now — isolate later if work policy requires.

## IoT (VLAN 40) — SSID `Hai-Fi Wai-Fi (IoT)` + wired hubs

Only devices needing **direct IP reachability** get reservations. Hub-managed bulbs/sensors do not need IPs.

| Name | Hardware | Static IP | Connection | Notes |
|------|----------|-----------|------------|-------|
| **Samsung TV** | Smart TV (Tizen) | `10.10.40.10` | WiFi `Hai-Fi Wai-Fi (IoT)` | HA; casting target |
| **Rusken** | Roborock vacuum | `10.10.40.11` | WiFi `Hai-Fi Wai-Fi (IoT)` | HA |
| **Philips Hue hub** | Hue Bridge | `10.10.40.12` | Wired (port 7) | HA → hub; bulbs via Zigbee |
| **IKEA Trådfri** | Dirigera/Gateway | `10.10.40.13` | Wired (port 8) | HA → hub; bulbs via Zigbee/Thread |
| **Nintendo Switch** | Console | `10.10.40.14` | WiFi `Hai-Fi Wai-Fi (IoT)` | Online gaming; local LAN play deferred |
| **Samsung Odyssey** | Smart Monitor | `10.10.40.15` | WiFi `Hai-Fi Wai-Fi (IoT)` | HA; casting target |
| **Chromecast** | Google Chromecast | `10.10.40.16` | WiFi `Hai-Fi Wai-Fi (IoT)` | Casting from trusted |

**Hue + Trådfri hubs:** Wired — CRS310 ports 7 and 8 (access VLAN 40).

## Guest (VLAN 50) — SSID `Hai-Fi Wai-Fi (Guest)`

No reservations. Client isolation ON. DHCP DNS is public resolvers (1.1.1.1 / 9.9.9.9).

## Home Assistant integrations

All use **servers → IoT ALLOW** from `10.10.30.20`:

| Integration | Target IP |
|-------------|-----------|
| Samsung TV | `10.10.40.10` |
| Roborock (Rusken) | `10.10.40.11` |
| Philips Hue hub | `10.10.40.12` |
| IKEA Trådfri hub | `10.10.40.13` |
| Samsung Odyssey | `10.10.40.15` |
| Chromecast | `10.10.40.16` |

## dnsmasq static reservations

| Hostname | IP | VLAN |
|----------|-----|------|
| `janus.lab.zdk.no` | `10.10.30.1` | 30 (servers GW; Unbound) |
| `truenas.lab.zdk.no` | `10.10.30.20` | 30 |
| `blocky.lab.zdk.no` | `10.10.30.21` | 30 |
| `headscale.lab.zdk.no` | `10.10.30.1` | 30 (Caddy → `127.0.0.1:8081`) |
| `crs310.lab.zdk.no` | `10.10.10.2` | 10 |
| `nordri.lab.zdk.no` | `10.10.30.11` | 30 |
| `sudri.lab.zdk.no` | `10.10.30.12` | 30 |
| `austri.lab.zdk.no` | `10.10.30.13` | 30 |
| `vestri.lab.zdk.no` | `10.10.30.14` | 30 |
| `zpi.lab.zdk.no` | `10.10.30.15` | 30 |
| `pingu.lab.zdk.no` | `10.10.20.10` | 20 |
| `socrates.lab.zdk.no` | `10.10.20.11` | 20 |
| `remorse.lab.zdk.no` | `10.10.20.12` | 20 |
| `peon.lab.zdk.no` | `10.10.20.13` | 20 |
| `pixel7.lab.zdk.no` | `10.10.20.14` | 20 |
| `samsung-tv.iot.lab.zdk.no` | `10.10.40.10` | 40 |
| `rusken.iot.lab.zdk.no` | `10.10.40.11` | 40 |
| `hue.iot.lab.zdk.no` | `10.10.40.12` | 40 |
| `tradfri.iot.lab.zdk.no` | `10.10.40.13` | 40 |
| `switch.iot.lab.zdk.no` | `10.10.40.14` | 40 |
| `odyssey.iot.lab.zdk.no` | `10.10.40.15` | 40 |
| `chromecast.iot.lab.zdk.no` | `10.10.40.16` | 40 |

MAC addresses: **deferred** — fill at deploy from dnsmasq leases; do not block Stage 2.

## VLAN assignment rationale

| Zone | Devices | Policy |
|------|---------|--------|
| **30 servers** | TrueNAS, nordri–vestri (Turing Pi), Zpi | Trusted + VPN; HA → IoT outbound |
| **20 trusted** | Laptops, desktop, phone | Reach servers + internet |
| **40 iot** | TV, hubs, cast targets, Switch | Internet + HA from servers only |

**Zpi:** Servers VLAN for audio casting; move to trusted if it becomes a daily driver.

**Nintendo Switch:** IoT zone; local multiplayer rules deferred — see [firewall-matrix.md](firewall-matrix.md).
