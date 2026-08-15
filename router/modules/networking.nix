{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
  vlanNames = builtins.attrNames C.vlans;
in
{
  imports = [ ./options.nix ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = lib.mkIf cfg.enableIpv6 1;
  };

  networking = {
    hostName = cfg.hostname;
    domain = C.domain;
    useDHCP = false;
    useNetworkd = true;
    # Custom nftables in ./firewall.nix
    firewall.enable = false;
    nat.enable = false;
  };

  systemd.network = {
    enable = true;

    netdevs = lib.listToAttrs (
      map (
        name:
        let
          vlan = C.vlans.${name};
        in
        {
          name = "30-vlan${toString vlan.id}";
          value = {
            netdevConfig = {
              Name = "vlan${toString vlan.id}";
              Kind = "vlan";
            };
            vlanConfig.Id = vlan.id;
          };
        }
      ) vlanNames
    );

    networks = {
      "10-wan" = {
        matchConfig.Name = cfg.wanInterface;
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = cfg.enableIpv6;
        };
        linkConfig.RequiredForOnline = "routable";
      };

      "20-lan-trunk" = {
        matchConfig.Name = cfg.lanTrunkInterface;
        networkConfig = {
          LinkLocalAddressing = "no";
          VLAN = map (n: "vlan${toString C.vlans.${n}.id}") vlanNames;
        };
        linkConfig.RequiredForOnline = "carrier";
      };
    }
    // lib.listToAttrs (
      map (
        name:
        let
          vlan = C.vlans.${name};
        in
        {
          name = "40-vlan${toString vlan.id}";
          value = {
            matchConfig.Name = "vlan${toString vlan.id}";
            address = [ vlan.ipv4 ];
            networkConfig = {
              ConfigureWithoutCarrier = true;
              IPv6AcceptRA = false;
            };
          };
        }
      ) vlanNames
    );
  };
}
