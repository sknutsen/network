{ lib, ... }:
let
  C = import ../lib/constants.nix;
  gw = cidr: lib.head (lib.splitString "/" cidr);
in
{
  # Split-horizon recursive resolver. Listens on VLAN gateways (not guest).
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [
          "127.0.0.1"
          (gw C.vlans.mgmt.ipv4)
          (gw C.vlans.trusted.ipv4)
          (gw C.vlans.servers.ipv4)
          (gw C.vlans.iot.ipv4)
        ];
        access-control = [
          "127.0.0.0/8 allow"
          "${C.vlans.mgmt.network} allow"
          "${C.vlans.trusted.network} allow"
          "${C.vlans.servers.network} allow"
          "${C.vlans.iot.network} allow"
          "${C.vpn.network} allow"
        ];
        hide-identity = true;
        hide-version = true;
        prefetch = true;
        private-domain = [ C.domain ];
        domain-insecure = [ C.domain ];
        local-zone = [
          ''"${C.domain}." static''
          ''"zdk.no." transparent''
        ];
        local-data = [
          ''"zdk.no. A ${C.hosts.truenas}"''
          ''"code.zdk.no. A ${C.hosts.truenas}"''
          ''"truenas.${C.domain}. A ${C.hosts.truenas}"''
          ''"blocky.${C.domain}. A ${C.hosts.blocky}"''
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
          # UniFi UI is on the router; point lab name at servers GW for now
          ''"unifi.${C.domain}. A ${gw C.vlans.servers.ipv4}"''
          ''"ha.${C.domain}. A ${C.hosts.truenas}"''
          ''"auth.${C.domain}. A ${C.hosts.truenas}"''
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
