{ vars, lib, ... }:
{
  imports = [ ./hardware.nix ];
  networking.hostName = "node01";
  # `mkDefault` : l'image Proxmox par-nœud (images/proxmox-image.nix, via le
  # format nixos-generators "proxmox" = nixpkgs virtualisation/proxmox-image.nix)
  # pose `networking.useDHCP = false;` en priorité normale (le réseau y est
  # géré par cloud-init) ; ce serait un conflit d'évaluation à priorité égale
  # sans `mkDefault` ici. Pour la config "réelle" node01 seule (sans le format
  # image), rien d'autre ne définit cette option : `mkDefault true` reste donc
  # la valeur effective.
  networking.useDHCP = lib.mkDefault true;

  # Explicite, pas seulement dérivé de networking.hostName : le format image
  # Proxmox (virtualisation/proxmox-image.nix) `mkForce`-ra networking.hostName
  # à "" dans l'IMAGE construite pour ce nœud (voir images/proxmox-image.nix) ;
  # sans cette ligne, le défaut de services.comin.hostname (qui vaut
  # config.networking.hostName) évaluerait à "" dans ce contexte-là et
  # déclencherait l'assertion de comin. La fixer ici la fait survivre à ce
  # mkForce et rend aussi explicite quel nixosConfigurations.<hostname> comin
  # doit converger/switcher pour ce nœud.
  services.comin.hostname = "node01";
}
