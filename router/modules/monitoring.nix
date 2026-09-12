{
  lib,
  pkgs,
  ...
}:
let
  C = import ../lib/constants.nix;
  gw = cidr: lib.head (lib.splitString "/" cidr);

  inventory = {
    macs = lib.mapAttrs' (name: mac: {
      name = lib.toLower mac;
      value = { inherit name; };
    }) C.macs;
    vlans = lib.mapAttrsToList (name: vlan: {
      inherit name;
      id = vlan.id;
      network = vlan.network;
    }) C.vlans;
  };

  exporter = pkgs.writers.writePython3Bin "network-presence-exporter" {
    flakeIgnore = [
      "E501"
      "W503"
    ];
  } (builtins.readFile ./network-presence-exporter.py);
in
{
  environment.etc."network-presence/inventory.json".text = builtins.toJSON inventory;

  services.prometheus.exporters.node = {
    enable = true;
    port = C.monitoring.nodeExporterPort;
    openFirewall = false; # opened selectively in firewall.nix
    enabledCollectors = [
      "systemd"
      "processes"
    ];
  };

  users.users.network-presence = {
    isSystemUser = true;
    group = "network-presence";
    extraGroups = [ "dnsmasq" ];
  };
  users.groups.network-presence = { };

  systemd.services.network-presence-exporter = {
    description = "Prometheus exporter for DHCP leases and ARP neighbors";
    wantedBy = [ "multi-user.target" ];
    after = [
      "dnsmasq.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = "network-presence";
      Group = "network-presence";
      SupplementaryGroups = [ "dnsmasq" ];
      ExecStart = "${lib.getExe exporter} --listen ${gw C.vlans.servers.ipv4}:${toString C.monitoring.presenceExporterPort}";
      Restart = "always";
      RestartSec = 5;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
