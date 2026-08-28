{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
in
{
  # Stage 6 — disabled until keys and peer list exist.
  config = lib.mkIf cfg.enableWireGuard {
    networking.wireguard.interfaces.wg0 = {
      ips = [ "10.10.255.1/24" ];
      listenPort = C.vpn.listenPort;
      # privateKeyFile = config.sops.secrets."wireguard/serverPrivateKey".path;
      privateKeyFile = "/run/secrets/wireguard/serverPrivateKey";
      peers = [
        # {
        #   name = "phone";
        #   publicKey = "...";
        #   allowedIPs = [ "10.10.255.2/32" ];
        # }
      ];
    };

    # Headscale on this host (Stage 6), not TrueNAS/k8s.
    # Listen 127.0.0.1:8081 — UniFi Inform owns :8080. Caddy vhost
    # headscale.lab.zdk.no (no Authelia; Tailscale login-server).
  };
}
