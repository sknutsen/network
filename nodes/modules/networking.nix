{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.node;
  C = import ../lib/constants.nix;
  gw = builtins.elemAt (lib.splitString "/" C.vlans.servers.ipv4) 0;
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
      address = [ "${cfg.address}/24" ];
      gateway = [ gw ];
      dns = [ gw ];
      domains = [ C.domain ];
      networkConfig = {
        IPv6AcceptRA = cfg.enableIpv6;
        DHCP = "no";
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
