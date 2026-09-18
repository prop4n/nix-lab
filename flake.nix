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
      # Une image Proxmox PAR NŒUD (pas un template générique) : comin fige
      # `services.comin.hostname` (donc le nixosConfigurations.<hostname> qu'il
      # doit converger/switcher) dans sa config YAML au moment de la
      # CONSTRUCTION de l'image ; un hostname posé au boot par cloud-init ne
      # peut pas rediriger un daemon comin déjà configuré pour un autre nom.
      # D'où : chaque image embarque directement la config du nœud visé
      # (modules/common + hosts/<hostName>), en plus des bits image-only de
      # images/proxmox-image.nix.
      mkProxmoxImage = hostName: nixos-generators.nixosGenerate {
        inherit system;
        format = "proxmox";
        specialArgs = { inherit inputs vars; };
        modules = [
          comin.nixosModules.comin
          sops-nix.nixosModules.sops
          ./modules/common
          (./hosts + "/${hostName}")
          ./images/proxmox-image.nix
        ];
      };
    in {
      nixosConfigurations = {
        node01 = mkHost "node01" [ ];
      };

      packages.${system}.image-node01 = mkProxmoxImage "node01";

      checks.${system}.node01-boot =
        import ./tests/node01-boot.nix { inherit pkgs inputs vars; };
    };
}
