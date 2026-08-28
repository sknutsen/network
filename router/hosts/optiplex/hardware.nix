# Hand-maintained OptiPlex bits. Filesystems come from disko.nix.
# nixos-anywhere --generate-hardware-config fills hardware-configuration.nix
# (initrd modules, firmware). Keep igb/e1000e here so WAN/LAN names exist
# even if generate-config runs before the i350 is visible.
{
  config,
  lib,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "igb" # Intel i350-T2
    "e1000e" # I217LM
  ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault false;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
