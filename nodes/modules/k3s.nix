{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.node;
  C = import ../lib/constants.nix;
  isServer = cfg.role == "server";
  serverFlags = [
    "--disable=traefik"
    "--disable=servicelb"
    "--disable=local-storage"
    "--node-taint=node-role.kubernetes.io/control-plane:NoSchedule"
  ]
  ++ map (san: "--tls-san=${san}") C.k3s.tlsSans;
  commonFlags = [
    "--node-label=homelab/kernel-profile=${cfg.kernelProfile}"
  ];
in
{
  config = lib.mkIf cfg.enableK3s {
    assertions = [
      {
        assertion = isServer || cfg.k3sTokenFile != null;
        message = "k3s agents need homelab.node.k3sTokenFile (sops path to the nordri node-token).";
      }
    ];

    environment.systemPackages = with pkgs; [
      k3s
      kubectl
      openiscsi
      nfs-utils
    ];

    # Longhorn and some charts expect this symlink on NixOS.
    systemd.tmpfiles.rules = [
      "L+ /usr/local/bin - - - - /run/current-system/sw/bin"
    ];

    systemd.services.k3s.path = with pkgs; [
      openiscsi
      nfs-utils
    ];

    networking.firewall.allowedTCPPorts = [
      C.k3s.kubeletPort
    ]
    ++ lib.optionals isServer [ C.k3s.apiPort ];
    networking.firewall.allowedUDPPorts = [ C.k3s.flannelVxlanPort ];

    services.k3s = {
      enable = true;
      role = cfg.role;
      clusterInit = isServer;
      tokenFile = cfg.k3sTokenFile;
      serverAddr = if isServer then "" else C.k3s.api;
      extraFlags = commonFlags ++ lib.optionals isServer serverFlags;
    };
  };
}
