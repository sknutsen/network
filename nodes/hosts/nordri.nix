{
  # Site knobs for nordri (server, 10.10.30.11).
  # Confirm interface + NVMe by-id at first boot.
  homelab.node = {
    hostname = "nordri";
    role = "server";
    address = "10.10.30.11";
    interface = "end0"; # observed first boot (GiyoMoon 25.11)
    kernelProfile = "mainline";
    diskLayout = "giyomoon-image";
    enableIpv6 = true; # lab ULA; no WAN v6
    enableK3s = false; # Stage 5
    enableLonghornPrep = true;
    k3sTokenFile = null;
  };
}
