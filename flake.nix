{
  description = "Homelab NixOS — Dell OptiPlex 9020 MT router (janus)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    sops-nix,
    disko,
    ...
  }: let
    system = "x86_64-linux";
  in {
    nixosConfigurations.optiplex = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit self;};
      modules = [
        sops-nix.nixosModules.sops
        disko.nixosModules.disko
        ./router/hosts/optiplex/configuration.nix
      ];
    };

    # RK1 cluster is a separate aarch64 flake:
    #   nix eval './nodes#nixosConfigurations.nordri.config.networking.hostName'

    formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
  };
}
