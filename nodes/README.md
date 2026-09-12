# RK1 nodes (Turing Pi 2.5)

NixOS flake for the k3s cluster. Configs: `nordri` (control plane),
`sudri` / `austri` / `vestri` (workers). Design sources:

- [docs/vlan-plan.md](../docs/vlan-plan.md)
- [docs/inventory.md](../docs/inventory.md)
- [docs/decisions.md](../docs/decisions.md)
- [docs/plans/rk1-bsp-fork.md](../docs/plans/rk1-bsp-fork.md)

This flake is **separate** from the repo-root router flake (`.#optiplex`).
All four nodes are on this flake with `enableK3s = true`. Flux/Helm live
under [k8s/README.md](../k8s/README.md).

## Layout

```
nodes/
├── flake.nix                 # aarch64 nixosConfigurations, deploy-rs, uboot
├── lib/constants.nix         # IPs mirrored from router (flake purity)
├── hosts/{nordri,sudri,austri,vestri}.nix
├── modules/                  # hardware, net, ssh, k3s, Longhorn prep
├── secrets/cluster.yaml      # sops-encrypted k3s token
└── bsp/                      # deferred vendor kernel — do not select
```

**Stage flags:** `enableK3s` is true. `kernelProfile` stays `"mainline"`.
`diskLayout` stays `"giyomoon-image"`. `interface` is `end0` (GiyoMoon
25.11). `diskDevice` is the NVMe by-id (unused until a disko reimage).

| Host | Slot | IPv4 / ULA | NIC | NVMe |
|------|------|------------|-----|------|
| nordri | 1 | `.11` / `::11` | `end0` `ba:ef:57:8b:58:5e` | Kingston 500G |
| sudri | 2 | `.12` / `::12` | `end0` `1e:86:1c:db:07:c1` | Kingston 500G |
| austri | 3 | `.13` / `::13` | `end0` `ce:a3:67:c6:1d:a4` | Samsung 2TB |
| vestri | 4 | `.14` / `::14` | `end0` `b6:51:50:02:89:03` | Kingston 2TB |

BMC and RK1s share the Turing onboard switch (both RJ45s are one L2).
One cable → CRS310 port 3. `turing-bmc.lab.zdk.no` is `10.10.30.30`.

## First flash (GiyoMoon image → NVMe)

U-Boot must stay on eMMC. The OS lives on NVMe. Follow
[GiyoMoon/nixos-turing-rk1](https://github.com/GiyoMoon/nixos-turing-rk1):

1. Flash their `nixos.img` to eMMC via the Turing Pi BMC UI. Power on.
2. Default login: `nixos` / `turing`. Copy `nixos.img` onto the node and
   `dd` it to NVMe (`/dev/nvme0n1`).
3. Power off. Flash `uboot.img` (BMC UI, or
   `nix build ./nodes#uboot-turing-rk1` on an `aarch64-linux` builder) to
   eMMC so the eMMC is U-Boot only.
4. Power on. Confirm root is `LABEL=NIXOS_SD` on `nvme0n1p2` and the NIC is
   `end0` (`ip -br link`).
5. Adopt this flake (next section). SSH keys for `zdk` and `root` match
   the router (remorse + pingu). Password SSH goes away.

Do not use `nixos-anywhere` on a running GiyoMoon root — it is an installer
and will fight the eMMC U-Boot + `NIXOS_SD` layout.

## Adopt / rebuild

From the **repo root**. Git flakes ignore untracked files — stage the tree
or pass `--flake "path:$PWD/nodes#nordri"`. Quote flake URIs (`#` is a
comment in bash/zsh).

After SSH keys work, **deploy-rs** is the usual path. `remoteBuild` is on, so
this Mac evaluates the flake and the node builds the aarch64 closure. Magic
rollback reverts a switch that drops SSH. `sshUser` is `zdk` (passwordless
sudo). Do not deploy a change that intentionally moves SSH (new address or
port) without `--magic-rollback=false`.

```bash
# One node (prefer this; same for sudri / austri / vestri).
# --skip-checks: skip pre-deploy `nix flake check`.
nix run './nodes' -- --skip-checks './nodes#nordri'

# Dry-run activation on the node:
nix run './nodes' -- --skip-checks --dry-activate './nodes#nordri'

# All four. Independent machines — do not roll back the ones that
# succeeded if one fails. When enabling k3s, do nordri first.
nix run './nodes' -- --skip-checks --rollback-succeeded=false './nodes'
```

On-node fallback (copy the flake over, or after you are already on the box):

```bash
sudo nixos-rebuild switch --flake '/path/to/nodes#nordri'
```

Eval (no build) from any flake-capable host:

```bash
nix eval './nodes#nixosConfigurations.nordri.config.networking.hostName'
nix eval './nodes#deploy.nodes.nordri.hostname'
```

## Stage 5 — k3s

Live: nordri is the sole control plane (`https://10.10.30.11:6443`, CP
taint kept). sudri / austri / vestri are agents. Token is
`sops.secrets."k3s/token"` from `secrets/cluster.yaml` (this flake;
sops-nix on each node at `/var/lib/sops-nix/key.txt`). Recipients:
cluster + pingu + remorse — not janus. Do not add kube-vip; `.10` stays
reserved.

Workers used a plaintext `/var/lib/rancher/k3s/node-token` for first
join; that file is gone. Override with `homelab.node.k3sTokenFile` only
if you must bypass sops.

Flux/Helm: [k8s/README.md](../k8s/README.md). Host iscsi +
`/var/lib/longhorn` is on (`enableLonghornPrep`).

Bundled k3s Traefik, ServiceLB, and local-path are disabled so Flux can
install Traefik, MetalLB (`10.10.30.100–110`), and Longhorn.

```bash
# after nordri k3s is up
ssh zdk@10.10.30.11 'sudo kubectl get nodes -o wide'
mkdir -p ~/.kube
ssh zdk@10.10.30.11 'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed 's#127.0.0.1#10.10.30.11#' > ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes -o wide
```

## Kernel profile

`mkHost { hostname = "nordri"; kernelProfile = "mainline"; }` (default).
Selecting `"bsp"` fails an assertion until `nodes/bsp/` is filled in.
Do not mix mainline and BSP nodes in one cluster.

## Leftovers

| Item | Status |
|------|--------|
| NIC name | Done — `end0` on all four |
| RK1 MACs | Done — reserved in router dnsmasq |
| NVMe by-id | Done — `diskDevice` set; still `giyomoon-image` |
| IPv6 ULA | Done — no WAN default route |
| k3s token / `cluster.yaml` | Done — encrypted `nodes/secrets/cluster.yaml` |
| sops-nix on nodes | Done — `/var/lib/sops-nix/key.txt` (cluster age key) |

Escape hatches (Ubuntu / Talos) if NixOS blocks progress:
[docs/reference/escape-hatches-ubuntu-talos.md](../docs/reference/escape-hatches-ubuntu-talos.md).
