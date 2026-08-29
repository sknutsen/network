# RK1 nodes (Turing Pi 2.5)

NixOS flake for the k3s cluster. Configs: `nordri` (control plane),
`sudri` / `austri` / `vestri` (workers). Design sources:

- [docs/vlan-plan.md](../docs/vlan-plan.md)
- [docs/inventory.md](../docs/inventory.md)
- [docs/decisions.md](../docs/decisions.md)
- [docs/plans/rk1-bsp-fork.md](../docs/plans/rk1-bsp-fork.md)

This flake is **separate** from the repo-root router flake (`.#optiplex`).
k3s stays **off** (`enableK3s = false`) until Stage 5. Flux/Helm live under
`k8s/` and are still stubs.

## Layout

```
nodes/
├── flake.nix                 # aarch64 nixosConfigurations + uboot package
├── lib/constants.nix         # IPs mirrored from router (flake purity)
├── hosts/{nordri,sudri,austri,vestri}.nix
├── modules/                  # hardware, net, ssh, k3s, Longhorn prep
└── bsp/                      # deferred vendor kernel — do not select
```

**Stage flags** in each host file: `enableK3s` stays false until static IPs
work and the nordri token is in sops. `kernelProfile` stays `"mainline"`.
`diskLayout` stays `"giyomoon-image"` after the first BMC flash.

## First flash (GiyoMoon image → NVMe)

U-Boot must stay on eMMC. The OS lives on NVMe. Follow
[GiyoMoon/nixos-turing-rk1](https://github.com/GiyoMoon/nixos-turing-rk1):

1. Flash their `nixos.img` to eMMC via the Turing Pi BMC UI. Power on.
2. Default login: `nixos` / `turing`. Copy `nixos.img` onto the node and
   `dd` it to NVMe (`/dev/nvme0n1`).
3. Power off. Flash `uboot.img` (BMC UI, or
   `nix build ./nodes#uboot-turing-rk1` on an `aarch64-linux` builder) to
   eMMC so the eMMC is U-Boot only.
4. Power on. Confirm `ip -br link` and set `homelab.node.interface` if it
   is not `enP2p33s0`. Confirm root is `LABEL=NIXOS_SD`.
5. Set the static IP from inventory (or rebuild this flake — it assigns
   `.11`–`.14`). SSH keys for `zdk` and `root` match the router.

BMC Ethernet is VLAN 10 (mgmt) only. Node NICs are VLAN 30 access (CRS310
port 3).

## Adopt this flake

From the **repo root**. Git flakes ignore untracked files — stage the tree
or pass `--flake "path:$PWD/nodes#nordri"`. Quote flake URIs in zsh.

The first rebuild after the vendor image replaces password SSH with
key-only. Keep BMC serial until that works.

```bash
# On the node (native aarch64):
nixos-rebuild switch --flake /path/to/net/nodes#nordri

# From a Linux workstation (after SSH from trusted VLAN):
nixos-rebuild switch --flake './nodes#nordri' --target-host root@10.10.30.11

# This Mac cannot build aarch64-linux locally. Use --build-on remote, or
# build on a node / a machine with boot.binfmt.emulatedSystems.
nixos-rebuild switch --flake './nodes#nordri' \
  --target-host root@10.10.30.11 --build-on remote
```

Eval (no build) from any flake-capable host:

```bash
nix eval './nodes#nixosConfigurations.nordri.config.networking.hostName'
```

## Stage 5 — k3s

1. Confirm static IPs: nordri `.11`, sudri `.12`, austri `.13`, vestri `.14`.
2. On nordri set `enableK3s = true` and rebuild. API is
   `https://10.10.30.11:6443`. Control-plane taint is set in `k3s.nix`
   (k3s does not taint CP by default; we add it).
3. `sudo cat /var/lib/rancher/k3s/server/node-token` → sops
   `secrets/cluster.yaml`. Point each agent's `k3sTokenFile` at that secret.
4. Set `enableK3s = true` on workers and rebuild. Do not add kube-vip;
   `.10` stays reserved.
5. Flux bootstrap and Longhorn Helm (`replica 3`, data
   `/var/lib/longhorn`) are `k8s/` work, not this flake. Host iscsi +
   directory prep is already on (`enableLonghornPrep`).

Bundled k3s Traefik, ServiceLB, and local-path are disabled so Flux can
install Traefik, MetalLB (`10.10.30.100–110`), and Longhorn.

## Kernel profile

`mkHost { hostname = "nordri"; kernelProfile = "mainline"; }` (default).
Selecting `"bsp"` fails an assertion until `nodes/bsp/` is filled in.
Do not mix mainline and BSP nodes in one cluster.

## First-boot leftovers

| Item | Notes |
|------|--------|
| NIC name | Confirm `enP2p33s0` vs `end0` |
| NVMe by-id | Fill `diskDevice` before any disko reimage |
| MACs | Inventory / dnsmasq — same deferred list as the router |
| k3s token | After nordri `enableK3s` |
| IPv6 | `enableIpv6` after Stage 2 PD |

Escape hatches (Ubuntu / Talos) if NixOS blocks progress:
[docs/reference/escape-hatches-ubuntu-talos.md](../docs/reference/escape-hatches-ubuntu-talos.md).
