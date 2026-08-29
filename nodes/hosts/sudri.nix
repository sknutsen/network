{
  # Site knobs for sudri (agent, 10.10.30.12).
  # Confirm interface + NVMe by-id at first boot.
  homelab.node = {
    hostname = "sudri";
    role = "agent";
    address = "10.10.30.12";
    interface = "enP2p33s0";
    kernelProfile = "mainline";
    diskLayout = "giyomoon-image";
    enableIpv6 = false;
    enableK3s = false; # Stage 5
    enableLonghornPrep = true;
    k3sTokenFile = null;
  };
}
