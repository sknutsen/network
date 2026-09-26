# Todo

Open work against the network as it is. The hosts are the source of truth:
`router/`, `nodes/`, `switch/`, `services/`, `k8s/`, and `secrets/`. These
items are gaps on that tree. They are not a build sequence, and they are not
stages to resume.

When an item is done, delete it here. If the work changes a choice, record
that in [decisions.md](decisions.md) and the matching brief.

NPU/GPU kernel work is a separate plan and is not on this list:
[plans/rk1-bsp-fork.md](plans/rk1-bsp-fork.md).

## WireGuard handshake (Remorse)

Classic `wg0` on janus already has the Remorse peer (`10.10.255.3`, public
key in `router/modules/vpn.nix`). Pixel (`10.10.255.2`) has a handshake from
LTE. Remorse does not.

From off the lab (not `Hai-Fi Wai-Fi`), bring the Mac tunnel up and confirm
a handshake. Procedure:
[runbooks/wireguard-clients.md](runbooks/wireguard-clients.md).

## WireGuard path

Forward from `wg0` is trusted, servers, and mgmt
(`router/modules/firewall.nix`). Caddy accepts `wg0` for lab vhosts. SSH
from `wg0` is denied.

That path has not been confirmed from Remorse. After the handshake, check
servers (`10.10.30.0/24`), CRS310 (`10.10.10.2`), and
`https://auth.lab.zdk.no` (split-horizon to `10.10.30.1`).

Lab IPv6 is not on this tunnel. `homelab.router.enableIpv6` is false (OBOS
Nett offers no IPv6). `wg0` is `10.10.255.1/24` only. Do not add v6 routes
to close this item.

## Jellyfin

The intended setup is already in the tree: TrueNAS app notes in
[services/jellyfin/README.md](../services/jellyfin/README.md), Caddy
`jellyfin.lab.zdk.no`, Blocky
[services/dns/iot-lab-allow.txt](../services/dns/iot-lab-allow.txt), and a
forward drop of `:30013`.

Confirm it is in effect on the hosts: the app listens on
`10.10.30.20:30013`, janus is running the Caddy and firewall from the flake,
and Blocky was reloaded with the allow file. Household only (trusted, VPN,
guest, TV `10.10.40.10`). Not WAN. If those checks pass, delete this item.
Do not start a second Jellyfin.

## DHCP reservations

Unbound names exist. dnsmasq reservations do not, because the MACs are
unknown (`router/lib/constants.nix` `macs`, `router/modules/dhcp.nix`):

| Host | Address |
|------|---------|
| Socrates | `10.10.20.11` |
| Peon | `10.10.20.13` |
| Nintendo Switch | `10.10.40.14` |

When a MAC is known, add it to `macs` and a `dhcp-host` row, and fill the
dash in [inventory.md](inventory.md). RK1 `end0` MACs are already reserved.

## Nintendo Switch local play

The console stays on IoT (`10.10.40.14`). Trusted → that address is not
allowed (the cast list in `firewall.nix` omits it). Local wireless play has
not been tested.

Test local play before changing policy. Options if it fails:
[decision-briefs.md](decision-briefs.md) brief 13. Do not move the console
to trusted as a first step.

## Longhorn off-cluster backup

Longhorn is already the default StorageClass: replica 3, data on
`/var/lib/longhorn` on each RK1. The recorded choice
([decisions.md](decisions.md), brief 6) also calls for off-cluster backup
(Velero, or ZFS snapshots on TrueNAS). That backup is not in `k8s/` or on
TrueNAS.

Add it against the live cluster, or remove it from the decision if replica
3 is enough.

## UPS

No UPS is installed. NUT is off on janus. Procure hardware before a power
test or a NUT module. Until then this stays deferred
([hardware-bom-norway.md](reference/hardware-bom-norway.md)).
