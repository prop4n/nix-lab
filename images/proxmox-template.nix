# Image générique : comin + cloud-init bakés, PAS de hostname ni de secret.
# cloud-init (via OpenTofu) posera le hostname et /var/lib/sops-nix/key.txt.
#
# ALIGNEMENT racine/boot avec hosts/node01/hardware.nix (exigence cross-tâche) :
# `nixos-generators` avec `format = "proxmox"` définit lui-même sa propre
# `fileSystems."/"` et son propre `boot.loader.grub` (device/partitionnement
# adaptés au disque virtuel qu'il fabrique). hosts/node01/hardware.nix déclare
# ses valeurs (root = /dev/disk/by-label/nixos, ext4 ; grub.devices = [ "/dev/sda" ])
# via `lib.mkDefault`, précisément pour laisser un format/priorité plus haute
# (comme celui de nixos-generators) l'emporter sans conflit d'évaluation.
# En conséquence : NE PAS surcharger ici fileSystems."/" ou boot.loader.grub —
# laisser le format "proxmox" définir le disque de l'image. L'exigence réelle
# est opérationnelle, pas une contrainte Nix : au moment de la construction de
# l'image (sur la machine de l'opérateur, hors de cet environnement), le
# device/label racine effectif du disque produit par le format "proxmox" doit
# correspondre à /dev/sda avec le label ext4 "nixos", pour que la VM démarrée
# à partir de ce template redémarre correctement une fois que comin bascule
# vers `.#node01` (qui s'attend à by-label/nixos sur /dev/sda). Si le format
# "proxmox" de nixos-generators produit un layout différent (autre label,
# autre disque), il faudra soit adapter hardware.nix, soit poser explicitement
# le label "nixos" sur la partition racine lors du provisioning Proxmox/OpenTofu.
#
# CONCERN découvert à l'évaluation (hors périmètre du commentaire ci-dessus,
# distinct du sujet fs/grub) : le module `comin` (via modules/common/comin.nix)
# a sa propre assertion — `services.comin.hostname` (qui vaut par défaut
# `config.networking.hostName`) DOIT être non vide, sinon l'évaluation de
# `system.build.toplevel` échoue ("You must set `networking.hostName` or
# `services.comin.hostname` explicitly"). C'est une tension architecturale
# réelle avec la consigne "PAS de hostname" de ce template : l'évaluation Nix
# a lieu au moment de la CONSTRUCTION de l'image (offline, chez l'opérateur),
# alors que cloud-init n'intervient qu'au BOOT de la VM (runtime) — un
# cloud-init runtime ne peut pas rendre non-vide une valeur Nix déjà figée
# dans la fermeture construite. Il est donc impossible de laisser ce champ
# réellement absent.
#
# Aggravant : le format `proxmox` de nixos-generators importe
# nixpkgs `virtualisation/proxmox-image.nix`, qui pose lui-même
# `networking.hostName = lib.mkForce "";` (générique par conception, pour que
# cloud-init fixe le hostname réel au 1er boot). `mkForce` (priorité 50) gagne
# sur tout `mkDefault` (priorité 1000) : poser `networking.hostName` ici via
# `mkDefault` ne suffit donc PAS à satisfaire l'assertion comin (le défaut de
# `services.comin.hostname` recalcule `config.networking.hostName`, qui reste
# ""). Solution retenue : fixer directement `services.comin.hostname` (option
# distincte, non liée par le `mkForce` ci-dessus) avec un placeholder explicite
# via `lib.mkDefault` — pas une identité de nœud réelle, juste ce qu'il faut
# pour que l'évaluation réussisse. À noter pour la tâche OpenTofu suivante :
# comin a besoin de connaître le VRAI hostname cible (ex. "node01") pour
# savoir quel `nixosConfigurations.<hostname>` converger/switcher — cette
# valeur étant figée à la construction de l'image, cloud-init (runtime,
# écriture de /etc/hostname) ne suffit PAS à la corriger ; il faudra soit
# construire une image par hôte avec le hostname réel injecté à l'évaluation
# (comme fait ce fichier avec le placeholder), soit un mécanisme hors Nix pour
# le faire converger après le 1er boot. À traiter explicitement dans la tâche
# OpenTofu.
{ modulesPath, lib, ... }:
{
  imports = [
    ../modules/common
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Placeholder générique requis par l'assertion comin (voir commentaire
  # ci-dessus) — PAS une identité de nœud réelle. Fixé directement sur
  # `services.comin.hostname` (et non `networking.hostName`, forcé à "" par
  # le format proxmox). `mkDefault` pour rester surchargeable proprement par
  # une composition ultérieure spécifique à un hôte, à l'image du pattern
  # utilisé dans hosts/node01/hardware.nix.
  services.comin.hostname = lib.mkDefault "proxmox-template";

  services.cloud-init = {
    enable = true;
    network.enable = true;
  };
  # cloud-init écrit la clé age et fixe le hostname au 1er boot.
  boot.growPartition = true;
  boot.loader.grub.enable = true;
}
