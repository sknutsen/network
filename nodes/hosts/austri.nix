{
  # Site knobs for austri (agent, 10.10.30.13).
  # Confirm interface + NVMe by-id at first boot.
  homelab.node = {
    hostname = "austri";
    role = "agent";
    address = "10.10.30.13";
    interface = "enP2p33s0";
    kernelProfile = "mainline";
    diskLayout = "giyomoon-image";
    enableIpv6 = false;
    enableK3s = false; # Stage 5
    enableLonghornPrep = true;
    k3sTokenFile = null;
  };
}
