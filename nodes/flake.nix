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
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    turing-rk1,
    sops-nix,
    disko,
    deploy-rs,
    ...
  }: let
    system = "aarch64-linux";
    lib = nixpkgs.lib;
    constants = import ./lib/constants.nix;
    pkgs = nixpkgs.legacyPackages.${system};

    # Workstations that run `deploy` (Macs + a node). Janus is not here.
    deploySystems = [
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    # Activation scripts from this pin; rust CLI from nixpkgs (cache, RK1 RAM).
    deployPkgs = import nixpkgs {
      inherit system;
      overlays = [
        deploy-rs.overlays.default
        (_self: super: {
          deploy-rs = {
            inherit (pkgs) deploy-rs;
            lib = super.deploy-rs.lib;
          };
        })
      ];
    };

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

    mkDeployNode = hostname: nixos: {
      hostname = constants.hosts.${hostname};
      profiles.system.path = deployPkgs.deploy-rs.lib.activate.nixos nixos;
    };
  in {
    nixosConfigurations = {
      nordri = mkHost { hostname = "nordri"; };
      sudri = mkHost { hostname = "sudri"; };
      austri = mkHost { hostname = "austri"; };
      vestri = mkHost { hostname = "vestri"; };
    };

    # sshUser zdk, passwordless sudo to root (common.nix). remoteBuild: Macs
    # can eval this flake but cannot build aarch64-linux closures.
    deploy = {
      sshUser = "zdk";
      user = "root";
      remoteBuild = true;
      nodes = lib.mapAttrs mkDeployNode self.nixosConfigurations;
    };

    checks.${system} = deployPkgs.deploy-rs.lib.deployChecks self.deploy;

    packages =
      lib.genAttrs deploySystems (sys: {
        deploy-rs = nixpkgs.legacyPackages.${sys}.deploy-rs;
      })
      // {
        ${system} = {
          uboot-turing-rk1 = turing-rk1.packages.${system}.uboot-turing-rk1;
          deploy-rs = nixpkgs.legacyPackages.${system}.deploy-rs;
        };
      };

    apps = lib.genAttrs deploySystems (sys: {
      default = {
        type = "app";
        program = "${nixpkgs.legacyPackages.${sys}.deploy-rs}/bin/deploy";
      };
    });

    formatter.${system} = pkgs.nixfmt-rfc-style;
  };
}
