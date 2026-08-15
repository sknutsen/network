{ lib, ... }:
{
  options.homelab.router = {
    wanInterface = lib.mkOption {
      type = lib.types.str;
      # TODO: set after `ip -br link` on OptiPlex (I217LM)
      default = "wan0";
      description = "Physical NIC toward ISP modem (bridge mode).";
    };

    lanTrunkInterface = lib.mkOption {
      type = lib.types.str;
      # TODO: set after identifying i350-T2 port 1
      default = "lan0";
      description = "Physical NIC for 802.1Q trunk to CRS310.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "janus";
      description = "System hostname (short).";
    };

    enableIpv6 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WAN DHCPv6-PD and per-VLAN /64s once ISP prefix is known.";
    };

    enableWireGuard = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stage 6 — WireGuard server on WAN.";
    };

    enableDnsUpdater = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stage 2+ — DNSUpdater → Domeneshop for zdk.no / code.";
    };

    enableUnifi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prepare host for UniFi OS Server (Podman + firewall holes).";
    };
  };
}
