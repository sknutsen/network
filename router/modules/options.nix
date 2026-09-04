{ lib, ... }:
{
  options.homelab.router = {
    wanInterface = lib.mkOption {
      type = lib.types.str;
      default = "wan0";
      description = "Physical NIC toward ISP modem (bridge mode). systemd.link names this from the I217LM MAC.";
    };

    lanTrunkInterface = lib.mkOption {
      type = lib.types.str;
      default = "lan0";
      description = "Physical NIC for 802.1Q trunk to CRS310. systemd.link names this from i350 port 1.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "janus";
      description = "System hostname (short).";
    };

    enableIpv6 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable WAN DHCPv6-PD and per-VLAN /64s (Stage 2, OBOS Nett).
        IoT IPv6 DNS DNAT also requires blockyIpv6 (Blocky GUA on VLAN 30).
      '';
    };

    blockyIpv6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "2a01:example:30::21";
      description = ''
        Blocky GUA on the servers VLAN, set after prefix delegation (typically
        the VLAN 30 /64 plus host token ::21). When enableIpv6 and enableBlocky
        are both on, IoT UDP/TCP 53/853 is DNATed here. Null = no IPv6
        intercept; IPv6 DNS to WAN is still dropped so clients fall back to
        IPv4 DNAT. No IPv6 masquerade — native /64s.
      '';
    };

    enableWireGuard = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stage 6 — WireGuard server on WAN.";
    };

    enableDnsUpdater = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "After the DNSUpdater repo ships a package — Domeneshop for zdk.no / code / img / ha.";
    };

    enableUnifi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prepare host for UniFi OS Server (Podman + firewall holes).";
    };

    enableCaddy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Caddy on this host (edge TLS). Caddyfile: services/caddy/Caddyfile.";
    };

    enableWanCaddy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stage 7 — accept WAN TCP 80/443 to local Caddy (no DNAT to TrueNAS).";
    };

    caddyEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "ACME account email. Set before first DNS-01 issuance (Stage 5 lab certs; Stage 7 public).";
    };

    enableBlocky = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Stage 4 — IoT DHCP DNS via Blocky (10.10.30.21); DNAT IoT :53/:853
        to Blocky (hardcoded resolvers); drop IoT DNS to the router; omit
        IoT domain-search. Off: IoT uses Unbound on the VLAN 40 gateway
        so DNS works before Blocky is deployed. Blocky itself runs on
        TrueNAS, not this host.
      '';
    };
  };
}
