# Stub so the flake evaluates before first install.
# Overwritten by nixos-anywhere:
#   --generate-hardware-config nixos-generate-config ./router/hosts/optiplex/hardware-configuration.nix
# Disko owns filesystems (--no-filesystems). Commit the generated file after install.
{
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
}
