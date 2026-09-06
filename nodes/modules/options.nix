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
      default = "end0";
      description = ''
        GiyoMoon 25.11 names the RK1 NIC end0 (observed on all four slots).
        Confirm at first boot (`ip -br link`) if a later image differs.
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
      default = true;
      description = ''
        Lab ULA on VLAN 30 (`fd10:10:10:30::<last-hextet>/64`) plus a route
        to `fd10:10:10::/48` via janus. No IPv6 default route (OBOS has no
        WAN v6). Off = IPv4 only.
      '';
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
