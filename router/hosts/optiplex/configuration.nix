{
  config,
  lib,
  pkgs,
  ...
}: let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMUD4Q4Mg/bYYjZp1NWhXCOzmOTfwDePpkA+jGAU0QGx sondreknutsen1@gmail.com" # remorse
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBkibUkmHzKXS0Q1mxZXLiCnooKH/8BWnNeNMGuQqwLD sondreknutsen1@gmail.com" # pingu
  ];
in {
  imports = [
    ./hardware.nix
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules
  ];

  # --- Site-specific knobs ---
  homelab.router = {
    hostname = "janus";
    wanInterface = "wan0"; # I217LM 34:17:eb:96:84:20
    lanTrunkInterface = "lan0"; # i350-T2 port 1 a0:36:9f:33:ae:96
    enableIpv6 = true; # Stage 2: WAN DHCPv6-PD + /64 per VLAN. Leave blockyIpv6 null until GUA known.
    blockyIpv6 = null; # set after PD, e.g. "<servers-/64>::21"
    enableWireGuard = false;
    enableDnsUpdater = false;
    enableUnifi = true;
    enableCaddy = true;
    enableWanCaddy = false; # WAN 80/443 for img.zdk.no and ha.zdk.no
    caddyEmail = "admin@zdk.no";
    enableBlocky = false; # Stage 4 — flip after Blocky answers on 10.10.30.21
  };

  # Confirm on the installer: lsblk -d -o NAME,SIZE,MODEL && ls -l /dev/disk/by-id/
  # Prefer a stable by-id path once you have it.
  disko.devices.disk.main.device = "/dev/sda";

  # Persistent names from burned-in MACs (port order: lower MAC = i350 port 1).
  systemd.network.links = {
    "10-wan" = {
      matchConfig.MACAddress = "34:17:eb:96:84:20";
      linkConfig.Name = "wan0";
    };
    "20-lan" = {
      matchConfig.MACAddress = "a0:36:9f:33:ae:96";
      linkConfig.Name = "lan0";
    };
    "30-spare" = {
      matchConfig.MACAddress = "a0:36:9f:33:ae:97";
      linkConfig.Name = "spare0";
    };
  };

  # Keep spare i350 port administratively unused.
  systemd.network.networks."25-spare" = {
    matchConfig.Name = "spare0";
    linkConfig.ActivationPolicy = "always-down";
    networkConfig.LinkLocalAddressing = "no";
  };

  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  users.users.zdk = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = sshKeys;
  };

  # No hashedPassword: SSH is key-only, so wheel sudo cannot prompt.
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = ["root" "zdk"];

  environment.systemPackages = with pkgs; [
    vim
    git
    tcpdump
    dig
    ethtool
    pciutils
    usbutils
  ];

  # Janus decrypts with /var/lib/sops-nix/key.txt. Recipients: secrets/.sops.yaml.
  # Caddy Domeneshop env is rendered in caddy.nix.
  sops.defaultSopsFile = ../../../secrets/router.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  system.stateVersion = "24.11";
}
