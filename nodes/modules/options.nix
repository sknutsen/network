{ lib, ... }:
{
  options.homelab.node = {
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "System hostname (short). Must match inventory (nordri / sudri / austri / vestri).";
    };

    role = lib.mkOption {
      type = lib.types.enum [
        "server"
        "agent"
      ];
      description = "k3s role. Only nordri is server; workers are agents.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      description = "Static IPv4 on VLAN 30 (no prefix). Prefix is /24 from vlan-plan.";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "enP2p33s0";
      description = ''
        Turing Pi 2.5 RK1 2.5GbE name on mainline. Confirm at first boot
        (`ip -br link`) — some images show end0 instead.
      '';
    };

    kernelProfile = lib.mkOption {
      type = lib.types.enum [
        "mainline"
        "bsp"
      ];
      default = "mainline";
      description = ''
        Fleet kernel profile. mainline = GiyoMoon / linuxPackages_latest.
        bsp is deferred (nodes/bsp + docs/plans/rk1-bsp-fork.md). Do not mix
        profiles in one k3s cluster.
      '';
    };

    diskLayout = lib.mkOption {
      type = lib.types.enum [
        "giyomoon-image"
        "disko"
      ];
      default = "giyomoon-image";
      description = ''
        giyomoon-image: root is LABEL=NIXOS_SD (first flash of the GiyoMoon
        sdImage to NVMe). disko: GPT + ext4 LABEL=nixos — only after a
        planned reimage; do not flip this on a running GiyoMoon root.
      '';
    };

    diskDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/nvme0n1";
      description = "NVMe for disko. Prefer /dev/disk/by-id/... once known.";
    };

    enableIpv6 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Accept RA on VLAN 30 after Stage 2 PD. IPv4 static stays.";
    };

    enableK3s = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stage 5 — start k3s. Leave off until static IPs and tokens exist.";
    };

    enableLonghornPrep = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Host prep for Longhorn (open-iscsi, /var/lib/longhorn). Helm chart is Flux, not this flake.";
    };

    k3sTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the cluster token (agents required; server may omit and
        generate one). Typical: sops-nix secret once secrets/cluster.yaml exists.
      '';
    };
  };
}
