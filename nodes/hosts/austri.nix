{
  # Site knobs for austri (agent, 10.10.30.13).
  # Confirm interface + NVMe by-id at first boot.
  homelab.node = {
    hostname = "austri";
    role = "agent";
    address = "10.10.30.13";
    interface = "end0"; # observed first boot (GiyoMoon 25.11)
    kernelProfile = "mainline";
    diskLayout = "giyomoon-image";
    diskDevice = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_2TB_S6P1NS0T611720V";
    enableIpv6 = true; # lab ULA; no WAN v6
    enableK3s = true; # Stage 5
    enableLonghornPrep = true;
  };
}
