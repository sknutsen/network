# Shared addressing — keep in sync with docs/vlan-plan.md, docs/inventory.md,
# and nodes/lib/constants.nix (nodes flake cannot import this file).
{
  domain = "lab.zdk.no";

  vlans = {
    mgmt = {
      id = 10;
      ipv4 = "10.10.10.1/24";
      network = "10.10.10.0/24";
      dhcpRange = {
        start = "10.10.10.100";
        end = "10.10.10.200";
        lease = "24h";
      };
    };
    trusted = {
      id = 20;
      ipv4 = "10.10.20.1/24";
      network = "10.10.20.0/24";
      dhcpRange = {
        start = "10.10.20.100";
        end = "10.10.20.250";
        lease = "24h";
      };
    };
    servers = {
      id = 30;
      ipv4 = "10.10.30.1/24";
      network = "10.10.30.0/24";
      dhcpRange = {
        start = "10.10.30.22";
        end = "10.10.30.50";
        lease = "24h";
      };
    };
    iot = {
      id = 40;
      ipv4 = "10.10.40.1/24";
      network = "10.10.40.0/24";
      dhcpRange = {
        start = "10.10.40.100";
        end = "10.10.40.250";
        lease = "1h";
      };
    };
    guest = {
      id = 50;
      ipv4 = "10.10.50.1/24";
      network = "10.10.50.0/24";
      dhcpRange = {
        start = "10.10.50.100";
        end = "10.10.50.250";
        lease = "1h";
      };
    };
  };

  hosts = {
    truenas = "10.10.30.20";
    caddy = "10.10.30.1"; # janus servers-VLAN address; Unbound for Caddy names
    blocky = "10.10.30.21";
    crs310 = "10.10.10.2";
    nordri = "10.10.30.11";
    sudri = "10.10.30.12";
    austri = "10.10.30.13";
    vestri = "10.10.30.14";
    zpi = "10.10.30.15";
    traefikLb = "10.10.30.100";
    pingu = "10.10.20.10";
    socrates = "10.10.20.11";
    remorse = "10.10.20.12";
    peon = "10.10.20.13";
    pixel7 = "10.10.20.14";
    samsungTv = "10.10.40.10";
    rusken = "10.10.40.11";
    hue = "10.10.40.12";
    tradfri = "10.10.40.13";
    switch = "10.10.40.14";
    odyssey = "10.10.40.15";
    chromecast = "10.10.40.16";
  };

  vpn = {
    network = "10.10.255.0/24";
    listenPort = 51820;
  };

  unifi = {
    # UniFi OS Server on this host (Podman / vendor installer)
    uiPort = 11443;
    informPort = 8080;
    stunPort = 3478;
    discoveryPort = 10001;
  };

  # Loopback only — Caddy proxies headscale.lab.zdk.no. Do not bind :8080
  # (UniFi Inform) or :11443 (UniFi UI).
  headscale = {
    listenAddress = "127.0.0.1";
    listenPort = 8081;
  };
}
