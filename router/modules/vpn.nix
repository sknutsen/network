{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
in
{
  # Stage 6 — disabled until keys and peer list exist (see OPEN-QUESTIONS.md).
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

    # Headscale co-location TBD — router vs TrueNAS/k8s (OPEN-QUESTIONS).
  };
}
