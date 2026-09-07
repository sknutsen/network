{
  # Site knobs for sudri (agent, 10.10.30.12).
  # Confirm interface + NVMe by-id at first boot.
  homelab.node = {
    hostname = "sudri";
    role = "agent";
    address = "10.10.30.12";
    interface = "end0"; # observed first boot (GiyoMoon 25.11)
    kernelProfile = "mainline";
    diskLayout = "giyomoon-image";
    diskDevice = "/dev/disk/by-id/nvme-KINGSTON_SNV2S500G_50026B76866B5691";
    enableIpv6 = true; # lab ULA; no WAN v6
    enableK3s = true; # Stage 5
    enableLonghornPrep = true;
  };
}
