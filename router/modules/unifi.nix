{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
  mgmtVlan = "vlan${toString C.vlans.mgmt.id}";
  mgmtIp = lib.head (lib.splitString "/" C.vlans.mgmt.ipv4);
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
    config.systemd.package
  ];
  podmanForUos = pkgs.writeShellScript "podman-for-uosserver" ''
    export PATH="/var/lib/uosserver/bin:/run/wrappers/bin:/run/wrappers:${podmanHelperPath}"
    exec ${podmanPackage}/bin/.podman-wrapped "$@"
  '';
  uosPath = "/var/lib/uosserver/bin:/run/wrappers/bin:/run/wrappers:${lib.makeBinPath [
    podmanForUos
    pkgs.netavark
    pkgs.aardvark-dns
    pkgs.crun
    pkgs.conmon
    pkgs.slirp4netns
    pkgs.passt
    pkgs.coreutils
    config.systemd.package
  ]}";
  uosUid = 1001; # explicit — auto-assigned uid is not available at eval time for systemd user@ units
  uosRuntimeDir = "/run/user/${toString uosUid}";
  uosStartScript = pkgs.writeShellScript "uosserver-start" ''
    export HOME=/home/uosserver
    export XDG_CONFIG_HOME=/home/uosserver/.config
    export XDG_DATA_HOME=/home/uosserver/.local/share
    export XDG_RUNTIME_DIR=${uosRuntimeDir}
    export CONTAINERS_STORAGE_CONF=/etc/uosserver/storage.conf
    export UOS_SYSTEM_IP=${mgmtIp}
    export PATH="${uosPath}"
    exec /var/lib/uosserver/bin/uosserver-service
  '';
  uosCleanupScript = pkgs.writeShellScript "uosserver-cleanup-stale" ''
    set +e
    SS=${pkgs.iproute2}/bin/ss
    KILL=${pkgs.coreutils}/bin/kill
    PKILL=${pkgs.procps}/bin/pkill
    SED=${pkgs.gnused}/bin/sed
    SLEEP=${pkgs.coreutils}/bin/sleep
    RUNUSER=${pkgs.util-linux}/bin/runuser

    # Host discovery client binds 127.0.0.1:11002; the binary shows as "discovery".
    $PKILL -u ${toString uosUid} -x discovery 2>/dev/null
    for pid in $($SS -H -ltnp 'sport = :11002' | $SED -n 's/.*pid=\([0-9]*\).*/\1/p'); do
      [ -n "$pid" ] && $KILL "$pid" 2>/dev/null
    done

    # Abrupt stops leave the named container in an unstartable "improper" state.
    $RUNUSER -u uosserver -- env \
      HOME=/home/uosserver \
      XDG_CONFIG_HOME=/home/uosserver/.config \
      XDG_DATA_HOME=/home/uosserver/.local/share \
      XDG_RUNTIME_DIR=${uosRuntimeDir} \
      CONTAINERS_STORAGE_CONF=/etc/uosserver/storage.conf \
      PATH="${uosPath}" \
      /var/lib/uosserver/bin/podman rm -f uosserver 2>/dev/null

    $SLEEP 0.5
  '';
  uosPreStartScript = pkgs.writeShellScript "uosserver-pre-start" ''
    set -eu
    IP=${pkgs.iproute2}/bin/ip
    GREP=${lib.getExe pkgs.gnugrep}
    SEQ=${pkgs.coreutils}/bin/seq
    SLEEP=${pkgs.coreutils}/bin/sleep
    SYSTEMCTL=${config.systemd.package}/bin/systemctl

    ${uosCleanupScript}

    ln -sfn /usr/bin/podman /var/lib/uosserver/bin/podman
    ln -sfn /run/wrappers/bin/newuidmap /var/lib/uosserver/bin/newuidmap
    ln -sfn /run/wrappers/bin/newgidmap /var/lib/uosserver/bin/newgidmap

    ID=${pkgs.coreutils}/bin/id
    UOS_UID=$($ID -u uosserver)
    UOS_RUNTIME="/run/user/''${UOS_UID}"

    # Rootless podman and the host discovery client need the lingering user D-Bus session.
    $SYSTEMCTL start "user@''${UOS_UID}.service"
    for i in $($SEQ 1 30); do
      if [ -S "''${UOS_RUNTIME}/bus" ]; then
        break
      fi
      $SLEEP 0.2
    done
    if [ ! -S "''${UOS_RUNTIME}/bus" ]; then
      echo "uosserver preStart: timed out waiting for user@''${UOS_UID} D-Bus" >&2
      exit 1
    fi

    for i in $($SEQ 1 30); do
      if $IP link show ${mgmtVlan} 2>/dev/null | $GREP -q 'state UP'; then
        break
      fi
      $SLEEP 0.2
    done

    # Discovery joins multicast with INADDR_ANY; a 224.0.0.0/4 route on WAN wins over vlan10.
    $IP route del 224.0.0.0/4 dev ${cfg.wanInterface} 2>/dev/null || true
    $IP route replace 224.0.0.0/4 dev ${mgmtVlan} scope link

    $SLEEP 1
  '';
  uosEnv = [
    "HOME=/home/uosserver"
    "XDG_CONFIG_HOME=/home/uosserver/.config"
    "XDG_DATA_HOME=/home/uosserver/.local/share"
    "XDG_RUNTIME_DIR=${uosRuntimeDir}"
    "CONTAINERS_STORAGE_CONF=/etc/uosserver/storage.conf"
    "UOS_SYSTEM_IP=${mgmtIp}"
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
      uid = uosUid;
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
      "L+ /var/lib/uosserver/bin/newuidmap - - - - /run/wrappers/bin/newuidmap"
      "L+ /var/lib/uosserver/bin/newgidmap - - - - /run/wrappers/bin/newgidmap"
      "L+ /var/lib/uosserver/bin/netavark - - - - ${lib.getExe' pkgs.netavark "netavark"}"
      "L+ /var/lib/uosserver/bin/aardvark-dns - - - - ${pkgs.aardvark-dns}/bin/aardvark-dns"
      "L+ /var/lib/uosserver/bin/crun - - - - ${lib.getExe pkgs.crun}"
      "L+ /var/lib/uosserver/bin/conmon - - - - ${lib.getExe pkgs.conmon}"
      "L+ /usr/libexec/podman/netavark - - - - ${lib.getExe' pkgs.netavark "netavark"}"
      "L+ /usr/libexec/podman/aardvark-dns - - - - ${pkgs.aardvark-dns}/bin/aardvark-dns"
    ];

    # Discovery client joins UDP multicast with INADDR_ANY; without a link-scoped
    # route the kernel picks wan0 and setsockopt(IP_ADD_MEMBERSHIP) fails (ENODEV).
    systemd.network.networks."40-vlan${toString C.vlans.mgmt.id}" = {
      routes = [
        {
          Destination = "224.0.0.0/4";
          Scope = "link";
        }
      ];
    };

    systemd.services.uosserver = {
      description = "UniFi OS Server";
      wantedBy = ["multi-user.target"];
      after = [
        "network-online.target"
        "systemd-networkd-wait-online.service"
        "dbus.service"
        "systemd-logind.service"
        "user@${toString uosUid}.service"
      ];
      wants = [
        "network-online.target"
        "systemd-networkd-wait-online.service"
        "user@${toString uosUid}.service"
      ];
      requires = [
        "user@${toString uosUid}.service"
      ];
      preStart = "${uosPreStartScript}";
      postStop = "${uosCleanupScript}";
      serviceConfig =
        uosServiceConfig
        // {
          ExecStart = "${uosStartScript}";
          RuntimeDirectoryPreserve = "yes";
          PermissionsStartOnly = true;
          TimeoutStopSec = "130s";
        };
    };

    # Vendor updater is optional; enabling it at boot makes nixos-rebuild fail
    # when the binary exits 1 (no container yet / not configured).
    systemd.services.uosserver-updater = {
      enable = false;
      description = "UniFi OS Server updater";
      after = ["uosserver.service"];
      serviceConfig =
        uosServiceConfig
        // {
          ExecStart = "${pkgs.writeShellScript "uosserver-updater-start" ''
            export HOME=/home/uosserver
            export XDG_CONFIG_HOME=/home/uosserver/.config
            export XDG_DATA_HOME=/home/uosserver/.local/share
            export XDG_RUNTIME_DIR=${uosRuntimeDir}
            export CONTAINERS_STORAGE_CONF=/etc/uosserver/storage.conf
            export PATH="${uosPath}"
            exec /var/lib/uosserver/bin/updater-service
          ''}";
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
