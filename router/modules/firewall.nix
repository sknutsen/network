# Intent from docs/firewall-matrix.md — Stage 2 starts restrictive; Stage 4 completes.
{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
  wan = cfg.wanInterface;
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

      define TRUENAS = ${C.hosts.truenas}
      define BLOCKY = ${C.hosts.blocky}
      define RFC1918 = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }

      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;

          ct state invalid drop
          ct state established,related accept
          iifname "lo" accept

          # ICMP (ping / PMTU)
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept

          # SSH — trusted VLAN only (no WAN, no mgmt, no VPN until Stage 6)
          iifname $TRUSTED tcp dport 22 accept

          # DNS / DHCP on LAN
          iifname { $MGMT, $TRUSTED, $SERVERS, $IOT } udp dport { 53, 67 } accept
          iifname { $MGMT, $TRUSTED, $SERVERS, $IOT } tcp dport 53 accept
          iifname $GUEST udp dport 67 accept

          # UniFi OS Server (on-router)
          iifname { $TRUSTED, $MGMT, $SERVERS } tcp dport ${toString C.unifi.uiPort} accept
          iifname { $MGMT, $TRUSTED, $SERVERS } tcp dport ${toString C.unifi.informPort} accept
          iifname { $MGMT, $TRUSTED, $SERVERS } udp dport { ${toString C.unifi.stunPort}, ${toString C.unifi.discoveryPort} } accept

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
          iifname $IOT oifname $WAN accept

          # --- Guest isolation ---
          iifname $GUEST ip daddr $RFC1918 drop
          iifname $GUEST oifname $WAN accept

          # --- Trusted ---
          iifname $TRUSTED oifname $SERVERS accept
          iifname $TRUSTED oifname $WAN accept
          # Cast targets (optional) — enable specific daddrs in Stage 4–5
          # iifname $TRUSTED ip daddr { ${C.hosts.samsungTv}, ${C.hosts.chromecast}, ${C.hosts.odyssey} } accept

          # --- Servers ---
          iifname $SERVERS oifname $WAN accept
          # HA → IoT
          iifname $SERVERS ip saddr $TRUENAS oifname $IOT accept

          # --- Mgmt ---
          iifname $MGMT oifname { $SERVERS, $WAN } accept

          # --- VPN (Stage 6) ---
          # iifname "wg0" oifname { $TRUSTED, $SERVERS, $MGMT } accept

          counter drop
        }

        chain iot_to_rfc1918 {
          # Blocky DNS only
          ip daddr $BLOCKY udp dport { 53, 853 } accept
          ip daddr $BLOCKY tcp dport { 53, 853 } accept
          # Deny other DNS to force Blocky
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
          # Stage 7: WAN DNAT 80/443 → TrueNAS Caddy
          # iifname $WAN tcp dport { 80, 443 } dnat to $TRUENAS
        }
      }
    '';
  };
}
