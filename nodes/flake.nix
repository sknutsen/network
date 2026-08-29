{
  description = "Homelab NixOS — Turing RK1 k3s nodes (nordri / sudri / austri / vestri)";

  inputs = {
    # Pin 25.11 with GiyoMoon (aarch64 k3s regressions on unstable: nixpkgs#495013).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Board U-Boot / first-flash image only. Do not follow nixpkgs — their
    # kernel pin is independent (GiyoMoon / homenix).
    turing-rk1.url = "github:GiyoMoon/nixos-turing-rk1";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    turing-rk1,
    sops-nix,
    disko,
    ...
  }: let
    system = "aarch64-linux";
    lib = nixpkgs.lib;

    mkHost = {
      hostname,
      kernelProfile ? "mainline",
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self turing-rk1; };
        modules = [
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./modules
          ./hosts/${hostname}.nix
          {
            homelab.node.kernelProfile = lib.mkDefault kernelProfile;
          }
        ];
      };
  in {
    nixosConfigurations = {
      nordri = mkHost { hostname = "nordri"; };
      sudri = mkHost { hostname = "sudri"; };
      austri = mkHost { hostname = "austri"; };
      vestri = mkHost { hostname = "vestri"; };
    };

    packages.${system}.uboot-turing-rk1 = turing-rk1.packages.${system}.uboot-turing-rk1;

    formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
  };
}
