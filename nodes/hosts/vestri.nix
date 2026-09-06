{
  # Site knobs for vestri (agent, 10.10.30.14).
  # Confirm interface + NVMe by-id at first boot.
  homelab.node = {
    hostname = "vestri";
    role = "agent";
    address = "10.10.30.14";
    interface = "end0"; # observed first boot (GiyoMoon 25.11)
    kernelProfile = "mainline";
    diskLayout = "giyomoon-image";
    enableIpv6 = true; # lab ULA; no WAN v6
    enableK3s = false; # Stage 5
    enableLonghornPrep = true;
    k3sTokenFile = null;
  };
}
