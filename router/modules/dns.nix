{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
  gw = cidr: lib.head (lib.splitString "/" cidr);
in
{
  # Split-horizon recursive resolver. Listens on VLAN gateways (not guest).
  # IoT is a listener only while Unbound is the IoT resolver; after Blocky,
  # queries from VLAN 40 are dropped in nftables and refused here too.
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [
          "127.0.0.1"
          (gw C.vlans.mgmt.ipv4)
          (gw C.vlans.trusted.ipv4)
          (gw C.vlans.servers.ipv4)
        ]
        ++ lib.optionals (!cfg.enableBlocky) [ (gw C.vlans.iot.ipv4) ];
        access-control = [
          "127.0.0.0/8 allow"
          "${C.vlans.mgmt.network} allow"
          "${C.vlans.trusted.network} allow"
          "${C.vlans.servers.network} allow"
          "${C.vpn.network} allow"
        ]
        ++ lib.optionals (!cfg.enableBlocky) [ "${C.vlans.iot.network} allow" ];
        hide-identity = true;
        hide-version = true;
        prefetch = true;
        private-domain = [ C.domain ];
        # Local A records for the public zone SERVFAIL if Domeneshop signs
        # zdk.no; lab is internal-only. Disable DNSSEC for both.
        domain-insecure = [
          C.domain
          "zdk.no"
        ];
        local-zone = [
          # static: unknown names NXDOMAIN (do not recurse lab to the internet).
          # Wildcard below sends one-label names (grafana.lab.zdk.no) to Caddy
          # for HTTPS; ACME is DNS-01, not this lookup. Exact local-data still
          # wins (nordri, pingu, …).
          ''"${C.domain}." static''
          ''"zdk.no." transparent''
        ];
        local-data = [
          ''"zdk.no. A ${C.hosts.caddy}"''
          ''"code.zdk.no. A ${C.hosts.caddy}"''
          ''"img.zdk.no. A ${C.hosts.caddy}"''
          ''"ha.zdk.no. A ${C.hosts.caddy}"''
          # TrueNAS UI via Caddy — host firewall allows same-subnet only.
          ''"truenas.${C.domain}. A ${C.hosts.caddy}"''
          ''"blocky.${C.domain}. A ${C.hosts.blocky}"''
          ''"crs310.${C.domain}. A ${C.hosts.crs310}"''
          ''"usw-nc.${C.domain}. A ${C.hosts.uswNc}"''
          ''"usw-lr.${C.domain}. A ${C.hosts.uswLr}"''
          ''"nordri.${C.domain}. A ${C.hosts.nordri}"''
          ''"sudri.${C.domain}. A ${C.hosts.sudri}"''
          ''"austri.${C.domain}. A ${C.hosts.austri}"''
          ''"vestri.${C.domain}. A ${C.hosts.vestri}"''
          ''"zpi.${C.domain}. A ${C.hosts.zpi}"''
          ''"janus.${C.domain}. A ${gw C.vlans.servers.ipv4}"''
          ''"pingu.${C.domain}. A ${C.hosts.pingu}"''
          ''"socrates.${C.domain}. A ${C.hosts.socrates}"''
          ''"remorse.${C.domain}. A ${C.hosts.remorse}"''
          ''"peon.${C.domain}. A ${C.hosts.peon}"''
          ''"pixel7.${C.domain}. A ${C.hosts.pixel7}"''
          ''"samsung-tv.iot.${C.domain}. A ${C.hosts.samsungTv}"''
          ''"rusken.iot.${C.domain}. A ${C.hosts.rusken}"''
          ''"hue.iot.${C.domain}. A ${C.hosts.hue}"''
          ''"tradfri.iot.${C.domain}. A ${C.hosts.tradfri}"''
          ''"switch.iot.${C.domain}. A ${C.hosts.switch}"''
          ''"odyssey.iot.${C.domain}. A ${C.hosts.odyssey}"''
          ''"chromecast.iot.${C.domain}. A ${C.hosts.chromecast}"''
          # UniFi UI is on this host :11443; lab name → Caddy (no extra views).
          # Browse https://10.10.10.1:11443 until a Caddy vhost exists.
          ''"unifi.${C.domain}. A ${gw C.vlans.servers.ipv4}"''
          ''"headscale.${C.domain}. A ${C.hosts.caddy}"''
          ''"ha.${C.domain}. A ${C.hosts.caddy}"''
          ''"immich.${C.domain}. A ${C.hosts.caddy}"''
          ''"auth.${C.domain}. A ${C.hosts.caddy}"''
          # Catch-all for HTTPS vhosts (grafana, capacitor, …). Exact
          # names above win. Apex has no wildcard match. Lab TLS is internal;
          ''"${C.domain}. A ${C.hosts.caddy}"''
          ''"*.${C.domain}. A ${C.hosts.caddy}"''
        ];
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = [
            "1.1.1.1"
            "9.9.9.9"
          ];
        }
      ];
    };
  };
}
