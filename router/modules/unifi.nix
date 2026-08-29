{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.router;
  C = import ../lib/constants.nix;
in
{
  # UniFi OS Server is a vendor Podman install (impure), not a nixpkgs service.
  # This module prepares the host: Podman, nix-ld (vendor ELF), persistence, ports.
  config = lib.mkIf cfg.enableUnifi {
    virtualisation.podman.enable = true;

    # Vendor linux-x64 installer and uosserver binaries are generic glibc ELFs.
    # Without nix-ld, NixOS stub-ld prints https://nix.dev/permalink/stub-ld.
    programs.nix-ld.enable = true;
    security.sudo.extraConfig = ''
      Defaults env_keep += "NIX_LD NIX_LD_LIBRARY_PATH"
    '';

    # Persistence path is canonical; bind-mount here if the installer differs.
    # Inform :8080 — Headscale must not bind this port (use 127.0.0.1:8081).
    systemd.tmpfiles.rules = [
      "d /var/lib/unifi-os-server 0750 root root -"
      "L+ /usr/bin/podman - - - - ${lib.getExe pkgs.podman}"
    ];

    environment.systemPackages = with pkgs; [
      podman
      slirp4netns
      passt # pasta networking (Ubiquiti 4.9.3+ default)
      iperf3
    ];

    # Document expected ports (nftables opens these in firewall.nix).
    # UI:     https://<router-lan-ip>:${toString C.unifi.uiPort}
    # Inform: http://<router-lan-ip>:${toString C.unifi.informPort}/inform
    #
    # Install (manual, once), after nixos-rebuild so nix-ld is active:
    #   1. Download UniFi OS Server linux-x64 installer from ui.com
    #   2. sudo ./linux-x64-*-x64
    #   3. UI :11443; Inform Host Override = 10.10.10.1 (not Caddy .30.1)
    #   4. UniFi is this host only — do not run Network Application on TrueNAS.
  };
}
