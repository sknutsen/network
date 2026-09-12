{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
in
{
  # Stage 6 — classic WireGuard. Headscale is a later step (loopback :8081).
  config = lib.mkIf cfg.enableWireGuard {
    sops.secrets."wireguard/serverPrivateKey" = { };

    networking.wireguard = {
      enable = true;
      useNetworkd = true;
      interfaces.wg0 = {
        ips = [ "10.10.255.1/24" ];
        listenPort = C.vpn.listenPort;
        privateKeyFile = config.sops.secrets."wireguard/serverPrivateKey".path;
        peers = [
          {
            # pixel
            publicKey = "r94FVy7TLMduVvAjxmF8z4MhoGG6b5eaZUiFJBHGDGY=";
            allowedIPs = [ "10.10.255.2/32" ];
          }
          {
            # remorse (away)
            publicKey = "OMimDADwlb+cjvzjiCuQLD3iL0RcvWumDsSA64Lx5WQ=";
            allowedIPs = [ "10.10.255.3/32" ];
          }
        ];
      };
    };

    # Headscale on this host (not TrueNAS/k8s).
    # Listen 127.0.0.1:8081 — UniFi Inform owns :8080. Caddy vhost
    # headscale.lab.zdk.no (no Authelia; Tailscale login-server).
  };
}
