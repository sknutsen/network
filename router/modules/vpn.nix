{ config, lib, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
in
{
  # Stage 6 — classic WireGuard (wg0) and Headscale are independent.
  # Headscale is a Tailscale login-server, not a replacement for wg0.
  config = lib.mkMerge [
    (lib.mkIf cfg.enableWireGuard {
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
    })

    (lib.mkIf cfg.enableHeadscale {
      environment.systemPackages = [ config.services.headscale.package ];

      services.headscale = {
        enable = true;
        address = C.headscale.listenAddress;
        port = C.headscale.listenPort;
        settings = {
          server_url = "https://headscale.${C.domain}";
          prefixes = {
            v4 = "100.64.0.0/10";
            # Module default; unused on VLANs while enableIpv6 is false.
            v6 = "fd7a:115c:a1e0::/48";
          };
          dns = {
            magic_dns = true;
            # Must differ from server_url host. Do not use lab.zdk.no —
            # Unbound already owns that zone.
            base_domain = "ts.zdk.no";
            override_local_dns = false;
          };
          derp = {
            # UniFi STUN already owns udp/3478. Embedded DERP later, on
            # another port. Clients fall back to the default public DERP
            # map if holepunch fails (LTE).
            server.enabled = false;
          };
        };
      };
    })
  ];
}
