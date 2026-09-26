# Unused services stay off. The router is the policy point.
{
  config,
  ...
}:
let
  cfg = config.homelab.node;
in
{
  hardware.bluetooth.enable = false;
  services.printing.enable = false;
  services.resolved.enable = false;
  services.avahi.enable = false;
  programs.command-not-found.enable = false;

  services.openssh = {
    listenAddresses = [
      {
        addr = cfg.address;
        port = 22;
      }
    ];
    settings = {
      AllowUsers = [
        "zdk"
        "root"
      ];
      X11Forwarding = false;
    };
  };
}
