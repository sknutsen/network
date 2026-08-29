# GPT + ext4 on NVMe. U-Boot lives on eMMC, so there is no ESP.
# Only applied when diskLayout = "disko".
{ config, lib, ... }:
let
  cfg = config.homelab.node;
in
{
  config = lib.mkIf (cfg.diskLayout == "disko") {
    disko.devices.disk.main = {
      type = "disk";
      device = cfg.diskDevice;
      content = {
        type = "gpt";
        partitions = {
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [ "-L" "nixos" ];
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
