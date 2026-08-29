{ config, ... }:
let
  cfg = config.homelab.node;
in
{
  # Conditional imports cannot depend on config. Flip this file when BSP
  # work starts: import ../bsp/modules/boards/turing-rk1.nix and stop using
  # mainline kernelPackages in hardware-rk1.nix. Until then, refuse bsp.
  assertions = [
    {
      assertion = cfg.kernelProfile == "mainline";
      message = ''
        homelab.node.kernelProfile = "bsp" is deferred.
        Revert mkHost / the host file to "mainline".
        See docs/plans/rk1-bsp-fork.md and nodes/bsp/README.md.
      '';
    }
  ];
}
