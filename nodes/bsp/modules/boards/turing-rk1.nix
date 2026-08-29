# Vendor DTB + kernel for kernelProfile = "bsp".
# Do not import until nodes/bsp packaging exists.
{lib, ...}: {
  assertions = [
    {
      assertion = false;
      message = "BSP board module is a stub. Revert kernelProfile to mainline. See nodes/bsp/README.md.";
    }
  ];
}
