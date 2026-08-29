{ ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
    # Router is the PEP (firewall-matrix). Node SSH is reachable from
    # trusted / mgmt / servers / VPN on VLAN 30; not from WAN.
    openFirewall = true;
  };
}
