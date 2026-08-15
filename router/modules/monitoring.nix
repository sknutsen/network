{ ... }:
{
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    openFirewall = false; # opened selectively in firewall.nix
    enabledCollectors = [
      "systemd"
      "processes"
    ];
  };
}
