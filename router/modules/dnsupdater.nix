{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.router;
in {
  # DNSUpdater flake module → Domeneshop A records for published names.
  # TOKEN/SECRET come from sops (never Nix options — those land in the store).
  # vpn is the WireGuard Endpoint. @ and code stay off until those WAN vhosts
  # are uncommented. Oneshot + timer: 30s after boot, then every interval.
  config = lib.mkIf cfg.enableDnsUpdater {
    sops.secrets = {
      "dnsupdater/domeneshopToken" = {};
      "dnsupdater/domeneshopSecret" = {};
    };

    sops.templates."dnsupdater.env" = {
      restartUnits = ["dns-updater.service"];
      content = ''
        TOKEN=${config.sops.placeholder."dnsupdater/domeneshopToken"}
        SECRET=${config.sops.placeholder."dnsupdater/domeneshopSecret"}
      '';
    };

    services.dns-updater = {
      enable = true;
      provider = "domeneshop";
      environmentFile = config.sops.templates."dnsupdater.env".path;
      interval = "5min";
      runOnStart = true;
      domeneshop = {
        domainName = "zdk.no";
        records = [
          {
            recordName = "img";
            type = "A";
          }
          {
            recordName = "ha";
            type = "A";
          }
          {
            recordName = "vpn";
            type = "A";
          }
        ];
      };
      logging.loki = {
        url = "http://10.10.30.101:3100/loki/api/v1/push";
        tags = "app=dns-updater,host=janus";
      };
    };

    systemd.services.dns-updater = {
      after = ["sops-install-secrets.service"];
      wants = ["sops-install-secrets.service"];
    };
  };
}
