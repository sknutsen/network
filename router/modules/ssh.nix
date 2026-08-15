{ ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Deploy keys: hosts/optiplex/configuration.nix.
  # Firewall: SSH accepted only from trusted VLAN (see firewall.nix).
}
