{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware.nix
    ../../modules
  ];

  # --- Site-specific knobs ---
  homelab.router = {
    hostname = "janus";
    wanInterface = "wan0"; # I217LM 34:17:eb:96:84:20
    lanTrunkInterface = "lan0"; # i350-T2 port 1 a0:36:9f:33:ae:96
    enableIpv6 = false;
    enableWireGuard = false;
    enableDnsUpdater = false;
    enableUnifi = true;
  };

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

  users.users.root.openssh.authorizedKeys.keys = [
    # TODO: add deploy key (OPEN-QUESTIONS #9)
    # "ssh-ed25519 AAAA... you@host"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMUD4Q4Mg/bYYjZp1NWhXCOzmOTfwDePpkA+jGAU0QGx sondreknutsen1@gmail.com"
  ];

  environment.systemPackages = with pkgs; [
    vim
    git
    tcpdump
    dig
    ethtool
    pciutils
    usbutils
  ];

  # sops-nix — enable once secrets/router.yaml + age key exist
  # sops.defaultSopsFile = ../../../secrets/router.yaml;
  # sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  system.stateVersion = "24.11";
}
