{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.node;
  C = import ../lib/constants.nix;
in
{
  config = lib.mkIf cfg.enableLonghornPrep {
    services.openiscsi = {
      enable = true;
      name = "iqn.2024-08.lab.zdk.no:${cfg.hostname}";
    };

    environment.systemPackages = with pkgs; [
      openiscsi
      nfs-utils
    ];

    systemd.tmpfiles.rules = [
      "d ${C.longhorn.dataPath} 0700 root root -"
    ];
  };
}
