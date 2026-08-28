{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.router;
in
{
  # DNSUpdater → Domeneshop for zdk.no / code (before Stage 7 WAN).
  # Packaging lives in https://github.com/sknutsen/DNSUpdater — do not add a
  # derivation in this flake until that repo ships a package/flake.
  config = lib.mkIf cfg.enableDnsUpdater {
    # sops.secrets."dnsupdater/env" = { };
    systemd.services.dnsupdater = {
      description = "Update Domeneshop DNS for zdk.no / code.zdk.no";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        # EnvironmentFile = config.sops.secrets."dnsupdater/env".path;
        # ExecStart = "${pkgs.dnsupdater}/bin/dnsupdater"; # package TBD
        ExecStart = "${pkgs.coreutils}/bin/true"; # placeholder until packaging settled
      };
    };
    systemd.timers.dnsupdater = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = "5m";
        Unit = "dnsupdater.service";
      };
    };
  };
}
