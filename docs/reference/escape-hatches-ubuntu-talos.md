# RK1 escape hatches: Ubuntu and Talos (reference)

**Chosen:** NixOS + k3s (GiyoMoon mainline). Use escape hatches only if NixOS bring-up blocks progress. See [decisions.md](../decisions.md).

| | NixOS + k3s (default) | Ubuntu 22.04 + k3s | Talos Linux |
|---|----------------------|-------------------|-------------|
| Docs | [GiyoMoon/nixos-turing-rk1](https://github.com/GiyoMoon/nixos-turing-rk1) | [Turing Pi k3s guide](https://docs.turingpi.com/docs/turing-pi2-kubernetes-installation) | [Sidero RK1 guide](https://docs.siderolabs.com/talos/v1.8/platform-specific-installations/single-board-computers/turing_rk1) |
| Management | `nixos-rebuild` / deploy-rs | SSH, apt | `talosctl` only |
| NPU/GPU | BSP fork plan (deferred) | Vendor kernel (easiest) | Not available |
| Flux/k8s layer | Identical in all cases | Identical | Identical |

**What transfers unchanged if switching:** `k8s/` Flux manifests, VLAN 30 IP plan, MetalLB pool, Longhorn, Traefik, Prometheus, Capacitor.

## Ubuntu escape hatch (summary)

1. Flash Ubuntu 22.04 to NVMe via BMC.
2. Static IPs on VLAN 30; Netplan config.
3. Install k3s: `curl -sfL https://get.k3s.io | sh -` on nordri (server), agents on sudri/austri/vestri.
4. Flux bootstrap as normal.

## Talos escape hatch (summary)

1. Flash Talos image via BMC; SPI U-Boot on eMMC.
2. `talosctl gen config` + apply machine configs.
3. Bootstrap Kubernetes; install k3s-compatible tooling or use standard K8s.
4. Flux bootstrap as normal.

## ARM64 cautions

- Verify images: `docker manifest inspect <image>` for `linux/arm64`.
- Pin nixpkgs for aarch64 k3s regressions ([nixpkgs#495013](https://github.com/NixOS/nixpkgs/issues/495013)).
