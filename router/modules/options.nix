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
        Enable WAN DHCPv6-PD and per-VLAN /64s. Off while OBOS Nett
        offers no IPv6.
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
      description = "WireGuard server on WAN (wg0).";
    };

    enableHeadscale = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Headscale on 127.0.0.1:8081 behind Caddy
        headscale.lab.zdk.no. UniFi Inform keeps :8080. No Authelia.
      '';
    };

    enableDnsUpdater = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        DNSUpdater → Domeneshop A records (img, ha, code, vpn). Token/secret
        from sops dnsupdater.*; Loki on 10.10.30.101. Oneshot timer
        (boot + 5min). Apex @ is not a homelab site.
      '';
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
      description = "Accept WAN TCP 80/443 to local Caddy (no DNAT to TrueNAS).";
    };

    caddyEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "ACME account email for DNS-01 (lab and public names).";
    };

    enableBlocky = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        IoT DHCP DNS via Blocky (10.10.30.21); DNAT IoT :53/:853
        to Blocky (hardcoded resolvers); drop IoT DNS to the router; omit
        IoT domain-search. Off: IoT uses Unbound on the VLAN 40 gateway.
        Blocky itself runs on TrueNAS, not this host.
      '';
    };
  };
}
