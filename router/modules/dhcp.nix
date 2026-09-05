{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;

  # MAC → IP (see docs/inventory.md). Multiple ethernet addrs share one IP.
  reservations = [
    { ethernet = C.macs.uswNc; name = "usw-nc"; ipAddress = C.hosts.uswNc; }
    { ethernet = C.macs.uswLr; name = "usw-lr"; ipAddress = C.hosts.uswLr; }
    { ethernet = C.macs.zpi; name = "zpi"; ipAddress = C.hosts.zpi; }
    { ethernet = C.macs.truenas; name = "truenas"; ipAddress = C.hosts.truenas; }
    { ethernet = C.macs.pingu; name = "pingu"; ipAddress = C.hosts.pingu; }
    { ethernet = C.macs.remorse; name = "remorse"; ipAddress = C.hosts.remorse; }
    {
      ethernet = [
        C.macs.pixel7Wifi1
        C.macs.pixel7Wifi2
      ];
      name = "pixel7";
      ipAddress = C.hosts.pixel7;
    }
    { ethernet = C.macs.hue; name = "hue"; ipAddress = C.hosts.hue; }
    { ethernet = C.macs.tradfri; name = "tradfri"; ipAddress = C.hosts.tradfri; }
  ];

  gw = cidr: lib.head (lib.splitString "/" cidr);

  iotDns =
    if cfg.enableBlocky then C.hosts.blocky else gw C.vlans.iot.ipv4;

  domainSearchLine = name:
    if name == "iot" && cfg.enableBlocky then
      "# IoT: no domain-search — Blocky denies lab names; don't probe\n"
    else
      "dhcp-option=tag:${name},option:domain-search,${C.domain}\n";

  vlanDhcpSections = lib.concatStrings (
    lib.mapAttrsToList (
      name: vlan: ''
        # VLAN ${toString vlan.id} (${name})
        interface=vlan${toString vlan.id}
        dhcp-range=set:${name},${vlan.dhcpRange.start},${vlan.dhcpRange.end},${vlan.dhcpRange.lease}
        dhcp-option=tag:${name},option:router,${gw vlan.ipv4}
        dhcp-option=tag:${name},option:dns-server,${
          if name == "iot" then
            iotDns
          else if name == "guest" then
            "1.1.1.1,9.9.9.9"
          else
            gw vlan.ipv4
        }
        ${domainSearchLine name}
      ''
    ) C.vlans
  );

  reservationLines = lib.concatMapStrings (
    r:
    let
      macs = if builtins.isList r.ethernet then lib.concatStringsSep "," r.ethernet else r.ethernet;
    in
    "dhcp-host=${macs},${r.name},${r.ipAddress},infinite\n"
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
