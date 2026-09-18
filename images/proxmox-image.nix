# Bits IMAGE UNIQUEMENT (boot/disque/cloud-init) pour un template Proxmox
# nixos-generators. Ce module ne porte PAS d'identité de nœud : ni hostname,
# ni `services.comin.hostname`, ni `../modules/common` (comin/sops/tailnet).
# L'identité vient de la config par-hôte (ex. hosts/node01), assemblée à côté
# de ce fichier par le helper `mkProxmoxImage` dans flake.nix — parce que
# `services.comin.hostname` (qui sélectionne `nixosConfigurations.<hostname>`
# côté comin) est figé au moment de la CONSTRUCTION de l'image, pas au boot :
# un changement de hostname par cloud-init au 1er boot ne peut pas rediriger
# un daemon comin dont la config YAML a déjà été générée avec un autre nom.
# D'où l'architecture "une image par nœud" plutôt qu'un template générique.
#
# cloud-init reste activé ici pour injecter, à l'instanciation (OpenTofu), la
# clé age privée par hôte dans /var/lib/sops-nix/key.txt (le secret, pas
# l'identité comin).
#
# ALIGNEMENT racine/boot avec hosts/node01/hardware.nix (exigence cross-tâche) :
# `nixos-generators` avec `format = "proxmox"` définit lui-même sa propre
# `fileSystems."/"` et son propre `boot.loader.grub` (device/partitionnement
# adaptés au disque virtuel qu'il fabrique). hosts/node01/hardware.nix déclare
# ses valeurs (root = /dev/disk/by-label/nixos, ext4 ; grub.devices = [ "/dev/sda" ])
# via `lib.mkDefault`, précisément pour laisser un format/priorité plus haute
# (comme celui de nixos-generators) l'emporter sans conflit d'évaluation. En
# conséquence : NE PAS surcharger ici fileSystems."/" ou boot.loader.grub —
# laisser le format "proxmox" définir le disque de l'image. L'exigence réelle
# est opérationnelle, pas une contrainte Nix : au moment de la construction
# réelle de l'image (sur la machine de l'opérateur, hors de cet
# environnement), le device/label racine effectif du disque produit par le
# format "proxmox" doit correspondre à /dev/sda avec le label ext4 "nixos",
# pour que la VM démarrée à partir de cette image redémarre correctement
# après un `switch` de comin (qui s'attend à by-label/nixos sur /dev/sda). Si
# le format "proxmox" de nixos-generators produit un layout différent (autre
# label, autre disque), il faudra soit adapter hardware.nix, soit poser
# explicitement le label "nixos" sur la partition racine lors du provisioning
# Proxmox/OpenTofu. À vérifier au moment du build réel (hors de cet
# environnement).
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  services.cloud-init = {
    enable = true;
    network.enable = true;
  };
  # cloud-init injecte la clé age privée par hôte au 1er boot (secret, pas
  # d'identité comin — voir commentaire d'en-tête).
  boot.growPartition = true;
  boot.loader.grub.enable = true;
}
