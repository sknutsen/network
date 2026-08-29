# RK1 BSP profile (deferred)

Vendor kernel / Mali / RKNPU. **Not selected.** Fleet stays on GiyoMoon
mainline until a workload needs NPU or GPU.

Plan: [docs/plans/rk1-bsp-fork.md](../../docs/plans/rk1-bsp-fork.md).

```
nodes/bsp/
├── flake.nix                      # empty outputs until packaging starts
├── pkgs/kernel/vendor.nix         # stub
├── pkgs/firmware/mali-g610.nix    # stub
├── modules/boards/turing-rk1.nix  # stub
└── README.md
```

Parent `nodes/flake.nix` `mkHost` takes `kernelProfile = "mainline" | "bsp"`.
`"bsp"` currently fails an assertion in `modules/profile.nix`. When this
tree is real: import `modules/boards/turing-rk1.nix` from `profile.nix`,
pin Joshua-Riek/linux-rockchip in `vendor.nix`, test on nordri only, then
flip the fleet. One profile per cluster.

U-Boot on eMMC stays GiyoMoon `uboot-turing-rk1` for both profiles.
