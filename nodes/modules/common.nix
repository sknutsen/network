{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.node;
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMUD4Q4Mg/bYYjZp1NWhXCOzmOTfwDePpkA+jGAU0QGx sondreknutsen1@gmail.com"
  ];
in
{
  networking.hostName = cfg.hostname;
  networking.domain = (import ../lib/constants.nix).domain;

  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";

  # RK1 RAM is tight; skip generated docs on the nodes.
  documentation.man.enable = lib.mkDefault false;
  documentation.nixos.enable = lib.mkDefault false;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "zdk"
    ];
    auto-optimise-store = true;
    builders-use-substitutes = true;
  };

  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  users.users.zdk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = sshKeys;
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim
    git
    dig
    ethtool
    tcpdump
  ];

  # sops-nix — enable once a cluster sops file + per-node age keys exist.
  # Keep the file inside this flake (nodes/secrets/) — ../secrets is out of tree.
  # sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  system.stateVersion = "25.11";
}
