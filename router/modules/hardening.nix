# Stage 8 security pass — unused services stay off. NUT/UPS is deferred.
{
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  programs.command-not-found.enable = false;

  hardware.bluetooth.enable = false;
  services.printing.enable = false;
  services.resolved.enable = false;
  # No APC / NUT until a UPS is procured (hardware-bom).
  power.ups.enable = false;

  # On-box resolver is Unbound, not systemd-resolved (127.0.0.53).
  networking.nameservers = [ "127.0.0.1" ];

  services.openssh.settings = {
    AllowUsers = [
      "zdk"
      "root"
    ];
    X11Forwarding = false;
  };
}
