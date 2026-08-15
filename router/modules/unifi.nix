{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
in
{
  # UniFi OS Server is a vendor Podman install (impure), not a nixpkgs service.
  # This module prepares the host: Podman, persistence path, docs for ports.
  config = lib.mkIf cfg.enableUnifi {
    virtualisation.podman.enable = true;

    # Persistence for UniFi OS Server data (installer default may differ — verify).
    systemd.tmpfiles.rules = [
      "d /var/lib/unifi-os-server 0750 root root -"
    ];

    environment.systemPackages = with pkgs; [
      podman
      # handy for set-inform / AP debug from the router
      iperf3
    ];

    # Document expected ports (nftables opens these in firewall.nix).
    # UI:     https://<router-lan-ip>:${toString C.unifi.uiPort}
    # Inform: http://<router-lan-ip>:${toString C.unifi.informPort}/inform
    #
    # Install (manual, once):
    #   1. Download UniFi OS Server linux-x64 installer from ui.com
    #   2. Ensure podman + slirp4netns meet Ubiquiti minimums
    #   3. Run installer as root; complete first-run wizard
    #   4. Devices → Device Updates & Settings → Inform Host Override
    #      = router LAN IP the AP can reach (often 10.10.10.1)
  };
}
