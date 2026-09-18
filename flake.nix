{
  description = "Homelab NixOS + comin GitOps";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    comin = { url = "github:nlewo/comin"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-generators = { url = "github:nix-community/nixos-generators"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { self, nixpkgs, comin, sops-nix, nixos-generators, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      vars = import ./vars.nix;
      mkHost = hostName: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs vars; };
          modules = [
            comin.nixosModules.comin
            sops-nix.nixosModules.sops
            ./modules/common
            (./hosts + "/${hostName}")
          ] ++ extraModules;
        };
    in {
      nixosConfigurations = {
        node01 = mkHost "node01" [ ];
      };

      packages.${system}.proxmox-template = nixos-generators.nixosGenerate {
        inherit system;
        format = "proxmox";
        specialArgs = { inherit inputs vars; };
        modules = [
          comin.nixosModules.comin
          sops-nix.nixosModules.sops
          ./images/proxmox-template.nix
        ];
      };
    };
}
