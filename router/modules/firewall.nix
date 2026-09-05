# Intent from docs/firewall-matrix.md — Stage 4 minus IoT DNS cutover (enableBlocky).
{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
  wan = cfg.wanInterface;
  iotDns6 = cfg.enableBlocky && cfg.enableIpv6 && cfg.blockyIpv6 != null;

  # First line has no indent so ${...} keeps column alignment; following lines
  # keep 10 spaces (nftables ruleset indent).
  iotDnsInput =
    if cfg.enableBlocky then
      ''iifname $IOT udp dport { 53, 853 } drop
          iifname $IOT tcp dport { 53, 853 } drop''
    else
      ''iifname $IOT udp dport 53 accept
          iifname $IOT tcp dport 53 accept'';

  iotWanDnsDrop =
    if cfg.enableBlocky then
      ''# Fallback if a DNS packet skips DNAT. oifname WAN so DNATed
          # packets (dest Blocky, oif servers) are not killed here.
          iifname $IOT oifname $WAN udp dport { 53, 853 } drop
          iifname $IOT oifname $WAN tcp dport { 53, 853 } drop''
    else
      "";

  iotBlocky6Forward =
    if iotDns6 then
      ''iifname $IOT ip6 daddr $BLOCKY6 udp dport { 53, 853 } accept
          iifname $IOT ip6 daddr $BLOCKY6 tcp dport { 53, 853 } accept''
    else
      "";

  iotDnsDnat =
    if cfg.enableBlocky then
      ''# IoT DNS intercept: 8.8.8.8:53 → Blocky, port preserved.
          # Conntrack un-DNATs replies so the client still sees 8.8.8.8.
          # No SNAT: Blocky logs real IoT IPs (TrueNAS default gw = 10.10.30.1).
          # DoH :443 cannot be redirected without breaking HTTPS.
          iifname $IOT udp dport { 53, 853 } dnat to $BLOCKY
          iifname $IOT tcp dport { 53, 853 } dnat to $BLOCKY''
    else
      "";

  iotDnsDnat6 =
    if iotDns6 then
      ''# IoT IPv6 DNS intercept — same as v4. No ip6 masquerade (native /64).
          iifname $IOT udp dport { 53, 853 } dnat to $BLOCKY6
          iifname $IOT tcp dport { 53, 853 } dnat to $BLOCKY6''
    else
      "";
in
{
  networking.nftables = {
    enable = true;
    flattenRulesetFile = true;
    ruleset = ''
      define WAN = ${wan}
      define MGMT = vlan${toString C.vlans.mgmt.id}
      define TRUSTED = vlan${toString C.vlans.trusted.id}
      define SERVERS = vlan${toString C.vlans.servers.id}
      define IOT = vlan${toString C.vlans.iot.id}
      define GUEST = vlan${toString C.vlans.guest.id}

      define NET_MGMT = ${C.vlans.mgmt.network}
      define NET_TRUSTED = ${C.vlans.trusted.network}
      define NET_SERVERS = ${C.vlans.servers.network}
      define NET_IOT = ${C.vlans.iot.network}
      define NET_GUEST = ${C.vlans.guest.network}
      define NET_VPN = ${C.vpn.network}
      define NET_LAB = 10.10.0.0/16
      define NET_LAB6 = ${C.ula.lab}

      define TRUENAS = ${C.hosts.truenas}
      define BLOCKY = ${C.hosts.blocky}
      define CRS310 = ${C.hosts.crs310}
      ${
        if iotDns6 then
          "define BLOCKY6 = ${cfg.blockyIpv6}"
        else
          ""
      }
      define RFC1918 = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }

      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;

          ct state invalid drop
          ct state established,related accept
          iifname "lo" accept

          # WAN DHCPv4 client. Discovers/offers are often broadcasts from
          # 0.0.0.0 / 255.255.255.255, so conntrack does not mark the reply
          # related. Stock NixOS firewall allows udp/68; we own nftables.
          # Sport 67 + WAN-only: do not open the DHCP *server* port on WAN.
          # DHCPv6-PD (udp/546) is gated on enableIpv6; meta nfproto ipv6
          # rather than ip6 nexthdr, which misses extension headers.
          iifname $WAN meta nfproto ipv4 udp sport 67 udp dport 68 accept
          ${
            if cfg.enableIpv6 then
              ''iifname $WAN meta nfproto ipv6 udp sport 547 udp dport 546 accept''
            else
              ""
          }

          # ICMP (ping / PMTU)
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept

          # SSH — trusted VLAN only (no WAN, no mgmt, no VPN SSH in v1)
          iifname $TRUSTED tcp dport 22 accept

          # Caddy on this host. LAN: trusted + servers (+ wg0). Not mgmt
          # (infrastructure-only). WAN 80/443 only with enableWanCaddy (Stage 7).
          ${
            if cfg.enableCaddy then
              ''iifname { $TRUSTED, $SERVERS } tcp dport { 80, 443 } accept''
            else
              ""
          }
          ${
            if cfg.enableCaddy && cfg.enableWireGuard then
              ''iifname "wg0" tcp dport { 80, 443 } accept''
            else
              ""
          }
          ${
            if cfg.enableWireGuard then
              ''iifname "wg0" udp dport 53 accept
          iifname "wg0" tcp dport 53 accept''
            else
              ""
          }
          ${
            if cfg.enableCaddy && cfg.enableWanCaddy then
              ''iifname $WAN tcp dport { 80, 443 } accept''
            else
              ""
          }

          # DNS / DHCP on LAN. Guest: DHCP only (public resolvers on WAN).
          # IoT: DHCP always. DNS to Unbound only until enableBlocky.
          # After cutover, prerouting DNAT sends IoT :53/:853 to Blocky
          # (including queries aimed at the gateway); INPUT drop is backup.
          iifname { $MGMT, $TRUSTED, $SERVERS } udp dport { 53, 67 } accept
          iifname { $MGMT, $TRUSTED, $SERVERS } tcp dport 53 accept
          iifname { $IOT, $GUEST } udp dport 67 accept
          ${iotDnsInput}

          # Avahi on this host (reflector vlan30 ↔ vlan40 only)
          iifname { $SERVERS, $IOT } udp dport 5353 accept

          # UniFi OS Server (on-router). UI: admins on trusted/servers/mgmt (+ wg0).
          # Inform/STUN/discovery: AP on mgmt; trusted/servers for set-inform debug.
          iifname { $TRUSTED, $MGMT, $SERVERS } tcp dport ${toString C.unifi.uiPort} accept
          iifname { $MGMT, $TRUSTED, $SERVERS } tcp dport ${toString C.unifi.informPort} accept
          iifname { $MGMT, $TRUSTED, $SERVERS } udp dport { ${toString C.unifi.stunPort}, ${toString C.unifi.discoveryPort} } accept
          ${
            if cfg.enableWireGuard then
              ''iifname "wg0" tcp dport ${toString C.unifi.uiPort} accept''
            else
              ""
          }

          # WireGuard WAN (Stage 6)
          ${
            if cfg.enableWireGuard then
              ''iifname $WAN udp dport ${toString C.vpn.listenPort} accept''
            else
              ""
          }

          # node_exporter — scrape from servers VLAN / VPN later
          iifname $SERVERS tcp dport 9100 accept

          counter drop
        }

        chain forward {
          type filter hook forward priority filter; policy drop;

          ct state invalid drop
          ct state established,related accept

          # --- IoT isolation ---
          iifname $IOT ip daddr $RFC1918 jump iot_to_rfc1918
          iifname $IOT ip6 daddr $NET_LAB6 drop
          ${iotBlocky6Forward}
          ${iotWanDnsDrop}
          iifname $IOT oifname $WAN accept

          # --- Guest isolation ---
          iifname $GUEST ip daddr $RFC1918 drop
          iifname $GUEST oifname $WAN accept

          # --- Trusted ---
          # App HTTP on TrueNAS is Caddy-only (this host OUTPUT, not forward).
          ip daddr $TRUENAS tcp dport { ${toString C.forgejo.uiPort}, 9091, 30041, 30103 } drop
          iifname $TRUSTED oifname $SERVERS accept
          iifname $TRUSTED ip daddr $CRS310 accept
          iifname $TRUSTED oifname $WAN accept
          # Trusted → specific IoT only (cast + vendor apps). Not the rest of VLAN 40.
          iifname $TRUSTED ip daddr { ${C.hosts.samsungTv}, ${C.hosts.chromecast}, ${C.hosts.odyssey}, ${C.hosts.hue}, ${C.hosts.tradfri} } accept

          # --- Servers ---
          iifname $SERVERS oifname $WAN accept
          # HA → IoT (v4 TrueNAS only; v6 any VLAN 30 — Matter needs ULA)
          iifname $SERVERS ip saddr $TRUENAS oifname $IOT accept
          iifname $SERVERS oifname $IOT meta nfproto ipv6 accept

          # --- Mgmt ---
          iifname $MGMT oifname { $SERVERS, $WAN } accept

          # --- VPN (Stage 6) ---
          # iifname "wg0" oifname { $TRUSTED, $SERVERS, $MGMT } accept

          counter drop
        }

        chain iot_to_rfc1918 {
          # Blocky DNS only (Stage 4+). Harmless no-op until 10.10.30.21 exists.
          ip daddr $BLOCKY udp dport { 53, 853 } accept
          ip daddr $BLOCKY tcp dport { 53, 853 } accept
          # Deny other DNS to force Blocky (or Unbound-on-gateway via INPUT)
          udp dport { 53, 853 } drop
          tcp dport { 53, 853 } drop
          # Deny rest of RFC1918 (incl. HA initiate-from-IoT)
          drop
        }

        chain output {
          type filter hook output priority filter; policy accept;
        }
      }

      table ip nat {
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          oifname $WAN masquerade
        }

        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
          ${iotDnsDnat}
          # Stage 7: WAN 80/443 is INPUT to local Caddy (enableWanCaddy), not DNAT.
        }
      }

      # Native /64s — no IPv6 masquerade. DNS intercept only.
      table ip6 nat {
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
          ${iotDnsDnat6}
        }
      }
    '';
  };
}
