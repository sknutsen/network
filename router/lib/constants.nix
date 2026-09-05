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
    uswNc = "10.10.10.3";
    uswLr = "10.10.10.4";
    turingBmc = "10.10.10.5";
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

  # Burned-in / observed MACs. dnsmasq reservations in modules/dhcp.nix.
  # u7Lite has no reserved IP yet (DHCP pool on VLAN 10).
  macs = {
    truenas = "cc:28:aa:42:c2:9d";
    uswNc = "f4:e2:c6:55:40:ab";
    uswLr = "d0:21:f9:b2:bf:5d";
    turingBmc = "d0:ea:11:6d:36:a9";
    turingNodes = "d0:ea:11:6d:36:a7"; # board 2.5GbE; RK1s have their own MACs
    u7Lite = "a8:9c:6c:b8:f6:27";
    zpi = "d8:3a:dd:cf:e1:75";
    zpiWifi = "d8:3a:dd:cf:e1:78"; # Wi-Fi; no reservation (eth is VLAN 30)
    pingu = "f0:2f:74:dd:e6:48";
    remorse = "96:5b:ef:ae:02:04";
    pixel7Wifi1 = "ee:15:ec:33:4e:84";
    pixel7Wifi2 = "76:37:82:bf:88:3d";
    hue = "ec:b5:fa:12:d3:7c";
    tradfri = "68:ec:8a:02:69:43";
    rusken = "b0:4a:39:a2:e9:20";
    samsungTv = "bc:45:5b:92:63:70";
    odyssey = "e8:aa:cb:df:cb:1e";
    chromecastWifi = "f4:f5:d8:5f:f1:7a";
    chromecastEth = "44:09:b8:01:80:87";
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
