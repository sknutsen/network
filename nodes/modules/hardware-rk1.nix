# Mainline Turing RK1 board bits, derived from GiyoMoon/nixos-turing-rk1
# (DTB, extlinux, NVMe/eMMC initrd). Their module also imports sd-image.nix
# and forces a first-flash root UUID — that is for image builds, not a
# running NVMe host, so it is not imported here. U-Boot stays on eMMC
# (turing-rk1#uboot-turing-rk1). Kernel is linuxPackages_latest (25.11).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.node;
  rootLabel = if cfg.diskLayout == "disko" then "nixos" else "NIXOS_SD";
in
{
  nixpkgs.hostPlatform = "aarch64-linux";

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [
      "nf_tables"
      "vxlan"
      "iscsi_tcp"
    ];
    kernelParams = [
      "root=LABEL=${rootLabel}"
      "rootfstype=ext4"
      "console=ttyS0,115200"
    ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible = {
        enable = true;
        configurationLimit = 5;
      };
    };
    initrd.includeDefaultModules = false;
    initrd.availableKernelModules = [
      "nvme"
      "mmc_block"
    ];
  };

  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "rockchip/rk3588-turing-rk1.dtb";

  fileSystems = lib.mkIf (cfg.diskLayout == "giyomoon-image") {
    "/" = {
      device = "/dev/disk/by-label/${rootLabel}";
      fsType = "ext4";
    };
  };
}
