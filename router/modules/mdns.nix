# Scoped mDNS: servers ↔ IoT only (Matter / HA). Not trusted or guest.
{
  services.avahi = {
    enable = true;
    ipv4 = true;
    ipv6 = true;
    reflector = true;
    allowInterfaces = [
      "vlan30"
      "vlan40"
    ];
    publish.enable = false;
  };
}
