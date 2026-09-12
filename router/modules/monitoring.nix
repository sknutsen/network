{
  config,
  lib,
  pkgs,
  ...
}:
let
  C = import ../lib/constants.nix;
  gw = cidr: lib.head (lib.splitString "/" cidr);
  serversIp = gw C.vlans.servers.ipv4;

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

  snmpYml = pkgs.writeText "snmp.yml" (
    builtins.replaceStrings [ "@SNMP_COMMUNITY@" ] [ C.monitoring.crs310SnmpCommunity ] (
      builtins.readFile ./snmp-exporter.yml
    )
  );
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
      ExecStart = "${lib.getExe exporter} --listen ${serversIp}:${toString C.monitoring.presenceExporterPort}";
      Restart = "always";
      RestartSec = 5;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # Local UniFi user `unpoller` (View Only). Password: sops unpoller/password.
  sops.secrets."unpoller/password" = {
    owner = "unifi-poller";
    group = "unifi-poller";
    restartUnits = [ "unifi-poller.service" ];
  };

  services.unpoller = {
    enable = true;
    prometheus.http_listen = "${serversIp}:${toString C.monitoring.unpollerPort}";
    influxdb.disable = true;
    unifi.defaults = {
      url = "https://127.0.0.1:${toString C.unifi.uiPort}";
      user = "unpoller";
      pass = config.sops.secrets."unpoller/password".path;
      verify_ssl = false;
      save_dpi = false;
      save_ids = false;
      hash_pii = false;
    };
  };

  systemd.services.unifi-poller = {
    after = [
      "sops-install-secrets.service"
      "uosserver.service"
    ];
    wants = [ "sops-install-secrets.service" ];
  };

  services.prometheus.exporters.snmp = {
    enable = true;
    port = C.monitoring.snmpExporterPort;
    listenAddress = serversIp;
    openFirewall = false;
    configurationPath = snmpYml;
  };
}
