{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
in
{
  # UniFi OS Server is a vendor Podman install (impure), not a nixpkgs service.
  # The linux-x64 installer cannot write /etc/systemd/system (Nix store symlink).
  # Run the installer once for binaries + uosserver user; units live here.
  config = lib.mkIf cfg.enableUnifi {
    virtualisation.podman.enable = true;

    programs.nix-ld.enable = true;
    security.sudo.extraConfig = ''
      Defaults env_keep += "NIX_LD NIX_LD_LIBRARY_PATH"
    '';

    users.groups.uosserver = {};
    users.users.uosserver = {
      isSystemUser = true;
      group = "uosserver";
      home = "/home/uosserver";
      createHome = true;
      linger = true;
      autoSubUidGidRange = true;
    };
    users.users.zdk.extraGroups = ["uosserver"];

    systemd.tmpfiles.rules = [
      "d /usr/local 0755 root root -"
      "d /usr/local/bin 0755 root root -"
      "d /var/lib/uosserver 0750 uosserver uosserver -"
      "d /var/lib/unifi-os-server 0750 root root -"
      "L+ /usr/bin/podman - - - - ${lib.getExe pkgs.podman}"
    ];

    systemd.services.uosserver = {
      description = "UniFi OS Server";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "simple";
        User = "uosserver";
        Group = "uosserver";
        ExecStart = "/var/lib/uosserver/bin/uosserver-service";
        WorkingDirectory = "/var/lib/uosserver";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    systemd.services.uosserver-updater = {
      description = "UniFi OS Server updater";
      wantedBy = ["multi-user.target"];
      after = ["uosserver.service"];
      serviceConfig = {
        Type = "simple";
        User = "uosserver";
        Group = "uosserver";
        ExecStart = "/var/lib/uosserver/bin/updater-service";
        WorkingDirectory = "/var/lib/uosserver";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    environment.systemPackages = with pkgs; [
      podman
      slirp4netns
      passt
      iperf3
    ];
  };
}
