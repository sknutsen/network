{ lib, ... }:
let
  C = import ../lib/constants.nix;

  # MAC → IP reservations filled at deploy (see docs/inventory.md).
  reservations = [
    # { ethernet = "00:00:00:00:00:00"; name = "truenas"; ipAddress = C.hosts.truenas; }
  ];

  gw = cidr: lib.head (lib.splitString "/" cidr);

  vlanDhcpSections = lib.concatStrings (
    lib.mapAttrsToList (
      name: vlan: ''
        # VLAN ${toString vlan.id} (${name})
        interface=vlan${toString vlan.id}
        dhcp-range=set:${name},${vlan.dhcpRange.start},${vlan.dhcpRange.end},${vlan.dhcpRange.lease}
        dhcp-option=tag:${name},option:router,${gw vlan.ipv4}
        dhcp-option=tag:${name},option:dns-server,${
          if name == "iot" then
            C.hosts.blocky
          else if name == "guest" then
            "1.1.1.1,9.9.9.9"
          else
            gw vlan.ipv4
        }
        dhcp-option=tag:${name},option:domain-search,${C.domain}

      ''
    ) C.vlans
  );

  reservationLines = lib.concatMapStrings (
    r: "dhcp-host=${r.ethernet},${r.name},${r.ipAddress},infinite\n"
  ) reservations;
in
{
  environment.etc."dnsmasq-homelab.conf".text = ''
    # Generated from router/lib/constants.nix
    ${vlanDhcpSections}
    ${reservationLines}
  '';

  services.dnsmasq = {
    enable = true;
    settings = {
      # DHCP only — Unbound is the recursive resolver.
      port = 0;
      domain = C.domain;
      expand-hosts = true;
      dhcp-authoritative = true;
      local = "/${C.domain}/";
      conf-file = "/etc/dnsmasq-homelab.conf";
    };
  };
}
