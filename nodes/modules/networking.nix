{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.node;
  C = import ../lib/constants.nix;
  gw = builtins.elemAt (lib.splitString "/" C.vlans.servers.ipv4) 0;
  gw6 = builtins.elemAt (lib.splitString "/" C.vlans.servers.ipv6) 0;
  address6 = C.cluster.${cfg.hostname}.address6;
in
{
  networking = {
    useDHCP = false;
    useNetworkd = true;
    firewall.enable = true;
  };

  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = cfg.interface;
      address = [ "${cfg.address}/24" ] ++ lib.optionals cfg.enableIpv6 [ "${address6}/64" ];
      gateway = [ gw ];
      dns = [ gw ];
      domains = [ C.domain ];
      # No IPv6 default route: janus RA would advertise one, but OBOS has no
      # WAN v6. Static ULA + /48 via janus covers lab VLANs (Matter / HA).
      networkConfig = {
        IPv6AcceptRA = false;
        DHCP = "no";
      };
      routes = lib.optionals cfg.enableIpv6 [
        {
          Destination = C.ula.lab;
          Gateway = gw6;
        }
      ];
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
