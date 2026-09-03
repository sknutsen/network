{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
  podmanPackage = config.virtualisation.podman.package;
  # Podman's nix wrapper prepends deps then inherits PATH, which includes the
  # non-capability newuidmap from /run/current-system/sw/bin. Call the unwrapped
  # binary with a PATH that only exposes /run/wrappers/bin/{newuidmap,newgidmap}.
  podmanHelperPath = lib.makeBinPath [
    pkgs.netavark
    pkgs.aardvark-dns
    pkgs.crun
    pkgs.conmon
    pkgs.slirp4netns
    pkgs.passt
    pkgs.coreutils
  ];
  podmanForUos = pkgs.writeShellScript "podman-for-uosserver" ''
    export PATH="/run/wrappers/bin:/run/wrappers:${podmanHelperPath}"
    exec ${podmanPackage}/bin/.podman-wrapped "$@"
  '';
  uosPath = "/run/wrappers/bin:/run/wrappers:${lib.makeBinPath [
    podmanForUos
    pkgs.netavark
    pkgs.aardvark-dns
    pkgs.crun
    pkgs.conmon
    pkgs.slirp4netns
    pkgs.passt
    pkgs.coreutils
  ]}";
  uosEnv = [
    "HOME=/home/uosserver"
    "XDG_CONFIG_HOME=/home/uosserver/.config"
    "XDG_DATA_HOME=/home/uosserver/.local/share"
    "XDG_RUNTIME_DIR=/run/uosserver-runtime"
    "CONTAINERS_STORAGE_CONF=/etc/uosserver/storage.conf"
    "PATH=${uosPath}"
  ];
  uosServiceConfig = {
    Type = "simple";
    User = "uosserver";
    Group = "uosserver";
    WorkingDirectory = "/var/lib/uosserver";
    Restart = "on-failure";
    RestartSec = "10s";
    Delegate = true;
    RuntimeDirectory = "uosserver-runtime";
    RuntimeDirectoryMode = "0700";
    Environment = uosEnv;
  };
in {
  # UniFi OS Server is a vendor Podman install (impure), not a nixpkgs service.
  # The linux-x64 installer cannot write /etc/systemd/system (Nix store symlink).
  # Run the installer once for binaries; units + rootless storage live here.
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

    # Rootless podman must not use /var/lib/containers (rootful, 0700 root).
    environment.etc."uosserver/storage.conf".text = ''
      [storage]
      driver = "overlay"
      runroot = "/run/uosserver-runtime/storage"
      graphroot = "/home/uosserver/.local/share/containers/storage"
    '';

    systemd.tmpfiles.rules = [
      "d /usr/local 0755 root root -"
      "d /usr/local/bin 0755 root root -"
      "d /usr/libexec/podman 0755 root root -"
      "d /var/lib/uosserver 0750 uosserver uosserver -"
      "d /var/lib/uosserver/bin 0755 root root -"
      "d /var/lib/uosserver/storage 0750 uosserver uosserver -"
      "d /home/uosserver 0750 uosserver uosserver -"
      "d /home/uosserver/.config 0750 uosserver uosserver -"
      "d /home/uosserver/.config/containers 0750 uosserver uosserver -"
      "d /home/uosserver/.local 0750 uosserver uosserver -"
      "d /home/uosserver/.local/share 0750 uosserver uosserver -"
      "d /home/uosserver/.local/share/containers 0750 uosserver uosserver -"
      "d /home/uosserver/.local/share/containers/storage 0750 uosserver uosserver -"
      "d /var/lib/unifi-os-server 0750 root root -"
      "L+ /usr/bin/podman - - - - ${podmanForUos}"
      "L+ /var/lib/uosserver/bin/podman - - - - ${podmanForUos}"
      "L+ /var/lib/uosserver/bin/netavark - - - - ${lib.getExe' pkgs.netavark "netavark"}"
      "L+ /var/lib/uosserver/bin/aardvark-dns - - - - ${pkgs.aardvark-dns}/bin/aardvark-dns"
      "L+ /var/lib/uosserver/bin/crun - - - - ${lib.getExe pkgs.crun}"
      "L+ /var/lib/uosserver/bin/conmon - - - - ${lib.getExe pkgs.conmon}"
      "L+ /usr/libexec/podman/netavark - - - - ${lib.getExe' pkgs.netavark "netavark"}"
      "L+ /usr/libexec/podman/aardvark-dns - - - - ${pkgs.aardvark-dns}/bin/aardvark-dns"
    ];

    systemd.services.uosserver = {
      description = "UniFi OS Server";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      preStart = ''
        ln -sfn /run/wrappers/bin/newuidmap /var/lib/uosserver/bin/newuidmap
        ln -sfn /run/wrappers/bin/newgidmap /var/lib/uosserver/bin/newgidmap
      '';
      serviceConfig =
        uosServiceConfig
        // {
          ExecStart = "/var/lib/uosserver/bin/uosserver-service";
          RuntimeDirectoryPreserve = "yes";
        };
    };

    # Vendor updater is optional; enabling it at boot makes nixos-rebuild fail
    # when the binary exits 1 (no container yet / not configured).
    systemd.services.uosserver-updater = {
      enable = false;
      description = "UniFi OS Server updater";
      after = ["uosserver.service"];
      preStart = ''
        ln -sfn /run/wrappers/bin/newuidmap /var/lib/uosserver/bin/newuidmap
        ln -sfn /run/wrappers/bin/newgidmap /var/lib/uosserver/bin/newgidmap
      '';
      serviceConfig =
        uosServiceConfig
        // {
          ExecStart = "/var/lib/uosserver/bin/updater-service";
        };
    };

    environment.systemPackages = [
      podmanPackage
      pkgs.netavark
      pkgs.aardvark-dns
      pkgs.crun
      pkgs.conmon
      pkgs.slirp4netns
      pkgs.passt
      pkgs.iperf3
    ];
  };
}
