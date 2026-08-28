# GPT + ESP + ext4 — matches router/README.md § Install.
# Set disko.devices.disk.main.device in configuration.nix (site knob).
{
  disko.devices.disk.main = {
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [
              "-F"
              "32"
              "-n"
              "BOOT"
            ];
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
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
}
