{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;

  # MAC → IP (see docs/inventory.md). Multiple ethernet addrs share one IP.
  reservations = [
    { ethernet = C.macs.uswNc; name = "usw-nc"; ipAddress = C.hosts.uswNc; }
    { ethernet = C.macs.uswLr; name = "usw-lr"; ipAddress = C.hosts.uswLr; }
    { ethernet = C.macs.turingBmc; name = "turing-bmc"; ipAddress = C.hosts.turingBmc; }
    { ethernet = C.macs.nordri; name = "nordri"; ipAddress = C.hosts.nordri; }
    { ethernet = C.macs.sudri; name = "sudri"; ipAddress = C.hosts.sudri; }
    { ethernet = C.macs.austri; name = "austri"; ipAddress = C.hosts.austri; }
    { ethernet = C.macs.vestri; name = "vestri"; ipAddress = C.hosts.vestri; }
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
    { ethernet = C.macs.rusken; name = "rusken"; ipAddress = C.hosts.rusken; }
    { ethernet = C.macs.samsungTv; name = "samsung-tv"; ipAddress = C.hosts.samsungTv; }
    { ethernet = C.macs.odyssey; name = "odyssey"; ipAddress = C.hosts.odyssey; }
    {
      ethernet = [
        C.macs.chromecastWifi
        C.macs.chromecastEth
      ];
      name = "chromecast";
      ipAddress = C.hosts.chromecast;
    }
  ];

  gw = cidr: lib.head (lib.splitString "/" cidr);

  iotDns =
    if cfg.enableBlocky then C.hosts.blocky else gw C.vlans.iot.ipv4;

  # option 6 must be forced on IoT: some clients omit it from the
  # parameter-request list and then write the gateway (10.10.40.1).
  dnsOptionLine = name:
    let
      servers =
        if name == "iot" then
          iotDns
        else if name == "guest" then
          "1.1.1.1,9.9.9.9"
        else
          gw C.vlans.${name}.ipv4;
      kind = if name == "iot" && cfg.enableBlocky then "dhcp-option-force" else "dhcp-option";
    in
    "${kind}=tag:${name},option:dns-server,${servers}\n";

  domainSearchLine = name:
    if name == "iot" && cfg.enableBlocky then
      "# IoT: no domain-search / no option 15 — Blocky denies lab names\n"
    else
      "dhcp-option=tag:${name},option:domain-search,${C.domain}\n";

  # Scoped domain= so option 15 is not sent on IoT after Blocky (a bare
  # domain=lab.zdk.no applies to every VLAN and becomes search lab.zdk.no).
  domainLines = lib.concatMapStrings (
    name:
    let vlan = C.vlans.${name};
    in
    if name == "iot" && cfg.enableBlocky then
      ""
    else
      "domain=${C.domain},${vlan.network}\n"
  ) (lib.attrNames C.vlans);

  vlanDhcpSections = lib.concatStrings (
    lib.mapAttrsToList (
      name: vlan: ''
        # VLAN ${toString vlan.id} (${name})
        interface=vlan${toString vlan.id}
        dhcp-range=set:${name},${vlan.dhcpRange.start},${vlan.dhcpRange.end},${vlan.dhcpRange.lease}
        # Tag dhcp-host rows outside the pool (Hue .12, etc.)
        dhcp-range=set:${name},${lib.head (lib.splitString "/" vlan.network)},static,${vlan.dhcpRange.lease}
        dhcp-option=tag:${name},option:router,${gw vlan.ipv4}
        ${dnsOptionLine name}${domainSearchLine name}
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
    ${domainLines}
    ${vlanDhcpSections}
    ${reservationLines}
  '';

  services.dnsmasq = {
    enable = true;
    settings = {
      # DHCP only — Unbound is the recursive resolver.
      # domain= is scoped per VLAN in dnsmasq-homelab.conf (not global).
      port = 0;
      expand-hosts = true;
      dhcp-authoritative = true;
      local = "/${C.domain}/";
      conf-file = "/etc/dnsmasq-homelab.conf";
    };
  };
}
