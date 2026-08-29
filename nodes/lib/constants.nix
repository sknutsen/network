# Keep in sync with router/lib/constants.nix, docs/vlan-plan.md, docs/inventory.md.
# This flake cannot import ../router (pure eval: flake source is nodes/ only).
{
  domain = "lab.zdk.no";

  vlans = {
    servers = {
      id = 30;
      ipv4 = "10.10.30.1/24";
      network = "10.10.30.0/24";
    };
  };

  hosts = {
    nordri = "10.10.30.11";
    sudri = "10.10.30.12";
    austri = "10.10.30.13";
    vestri = "10.10.30.14";
  };

  k3s = {
    api = "https://10.10.30.11:6443";
    apiPort = 6443;
    kubeletPort = 10250;
    flannelVxlanPort = 8472;
    tlsSans = [
      "10.10.30.11"
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
    };
    sudri = {
      role = "agent";
      address = "10.10.30.12";
    };
    austri = {
      role = "agent";
      address = "10.10.30.13";
    };
    vestri = {
      role = "agent";
      address = "10.10.30.14";
    };
  };
}
