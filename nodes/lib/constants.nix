# Keep in sync with router/lib/constants.nix, docs/vlan-plan.md, docs/inventory.md.
# This flake cannot import ../router (pure eval: flake source is nodes/ only).
{
  domain = "lab.zdk.no";

  # Lab ULA (janus RA). Not ISP — OBOS Nett has no IPv6.
  ula = {
    lab = "fd10:10:10::/48";
  };

  vlans = {
    servers = {
      id = 30;
      ipv4 = "10.10.30.1/24";
      ipv6 = "fd10:10:10:30::1/64";
      network = "10.10.30.0/24";
      network6 = "fd10:10:10:30::/64";
    };
  };

  hosts = {
    nordri = "10.10.30.11";
    sudri = "10.10.30.12";
    austri = "10.10.30.13";
    vestri = "10.10.30.14";
  };

  # Same last hextet as IPv4 (mnemonic, not a numeric conversion).
  hosts6 = {
    nordri = "fd10:10:10:30::11";
    sudri = "fd10:10:10:30::12";
    austri = "fd10:10:10:30::13";
    vestri = "fd10:10:10:30::14";
  };

  k3s = {
    api = "https://10.10.30.11:6443";
    apiPort = 6443;
    kubeletPort = 10250;
    flannelVxlanPort = 8472;
    metallbMemberlistPort = 7946;
    longhornTcpPorts = [
      3260
      8000
      8001
      8443
      9500
      9501
      9502
      9503
      9504
    ];
    tlsSans = [
      "10.10.30.11"
      "fd10:10:10:30::11"
      "nordri.lab.zdk.no"
    ];
  };

  longhorn = {
    dataPath = "/var/lib/longhorn";
  };

  cluster = {
    nordri = {
      role = "server";
      address = "10.10.30.11";
      address6 = "fd10:10:10:30::11";
    };
    sudri = {
      role = "agent";
      address = "10.10.30.12";
      address6 = "fd10:10:10:30::12";
    };
    austri = {
      role = "agent";
      address = "10.10.30.13";
      address6 = "fd10:10:10:30::13";
    };
    vestri = {
      role = "agent";
      address = "10.10.30.14";
      address6 = "fd10:10:10:30::14";
    };
  };
}
