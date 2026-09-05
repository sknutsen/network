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
          DHCP = if cfg.enableIpv6 then "yes" else "ipv4";
          IPv6AcceptRA = cfg.enableIpv6;
        };
        linkConfig.RequiredForOnline = "routable";
      }
      // lib.optionalAttrs cfg.enableIpv6 {
        # DHCPv6-PD when the ISP offers it. OBOS Nett does not (2026-09).
        # WithoutRA + DHCPv6Client=always: start PD without waiting for RA.
        # UseAddress=no: IA_PD only — many ISPs ignore Solicit+IA_NA.
        dhcpV6Config = {
          WithoutRA = "solicit";
          PrefixDelegationHint = "::/56";
          UseAddress = false;
        };
        ipv6AcceptRAConfig = {
          DHCPv6Client = "always";
          UseDNS = false;
        };
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
            }
            // lib.optionalAttrs cfg.enableIpv6 {
              DHCPPrefixDelegation = true;
              IPv6SendRA = true;
            };
          }
          // lib.optionalAttrs cfg.enableIpv6 {
            # SubnetId 0x10/0x20/… matches vlan-plan nibble carving.
            # Token ::1 → gateway is <prefix>::1 on each VLAN.
            dhcpPrefixDelegationConfig = {
              UplinkInterface = cfg.wanInterface;
              SubnetId = "0x${toString vlan.id}";
              Announce = true;
              Token = "::1";
            };
          };
        }
      ) vlanNames
    );
  };
}
