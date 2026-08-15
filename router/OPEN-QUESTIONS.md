# Router bring-up — open questions

Resolved answers should update `hosts/optiplex/configuration.nix`,
`lib/constants.nix`, and the matching docs. Cross off when done.

## Hardware / install

1. [x] **Fresh NixOS install** (not an in-place upgrade).
2. [x] **Disk layout (recommended → adopted):** GPT, 512 MiB ESP `BOOT` → `/boot` (vfat), remainder ext4 `nixos` → `/`. Optional 4 GiB swap if RAM ≤ 8 GiB. See README § Install.
3. [x] **NIC MACs** (wired into systemd.link → `wan0` / `lan0` / `spare0`):
   - I217LM WAN: `34:17:eb:96:84:20` → `wan0`
   - i350 port 1 (assumed lower MAC): `a0:36:9f:33:ae:96` → `lan0` trunk
   - i350 port 2: `a0:36:9f:33:ae:97` → `spare0` (always-down)
   - **Confirm** port↔MAC mapping with a cable on port 1 after first boot (`ethtool -p lan0` or unplug test).
4. [x] **Hostname:** `janus` (`janus.lab.zdk.no`).

## ISP / WAN

5. [x] **WAN type:** DHCP (no PPPoE).
6. **ISP name** (for vlan-plan IPv6 table).
7. **IPv6 PD:** enable in Stage 2 immediately, or land IPv4-only first?
8. **Modem bridge mode:** already set, or still to configure?

## Access / identity

9. **SSH public keys** for root (and optional admin user)?
10. **Admin username** (`zdk` / other) vs root-only deploy?
11. [x] **SSH sources:** **trusted VLAN only** (not mgmt/servers/guest). VPN SSH deferred to Stage 6.

## UniFi OS Server

12. **Inform Host IP:** `10.10.10.1` (mgmt), `10.10.30.1` (servers), or another?
13. **AP management / native VLAN on CRS310 trunk:** untagged VLAN 10 for U7 Lite?
14. **UniFi OS Server data path** if installer default ≠ `/var/lib/unifi-os-server`?
15. **Podman version on NixOS 24.11** vs Ubiquiti minimum (4.3+ / pasta / slirp4netns) — verify before install.
16. **Migrate or abandon** the half-configured TrueNAS UniFi Network Application instance?

## DHCP / DNS

17. **MAC addresses** for static reservations (inventory still blank)?
18. **Guest DNS:** confirm public 1.1.1.1/9.9.9.9 at Stage 2 (Blocky later optional)?
19. **`unifi.lab.zdk.no`:** resolve to servers GW (`10.10.30.1`) only, or also publish on mgmt/trusted GWs via multiple A records / view?

## VPN / DDNS (can wait for Stage 6 / late Stage 2)

20. **WireGuard listen port** — keep `51820`?
21. **Headscale host:** router, TrueNAS, or k8s?
22. **DNSUpdater packaging:** flake input / custom derivation / prebuilt binary from sknutsen/DNSUpdater?
23. **Domeneshop API token** — sops key bootstrap process (age key location on router)?

## Deploy workflow

24. **How will you apply configs?** `nixos-rebuild` on-box, `deploy-rs`, Colmena, or copy closures?
25. **Flake lock:** commit `flake.lock` from a machine with Nix network access?
26. **nixpkgs channel:** stick to `nixos-24.11` or move to `25.05` / unstable for newer Podman?

## Firewall sequencing

27. **Stage 2 vs Stage 4:** is the scaffolded nftables set OK for first traffic, or start with a temporary “allow all LAN forward” until VLANs are proven?
28. **Trusted → IoT cast rules:** enable at Stage 3 WiFi test, or wait until HA is up?
