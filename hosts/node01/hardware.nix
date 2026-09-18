# Le filesystem racine et le device grub de node01 sont définis ici comme
# défauts machine : requis pour que `nixosConfigurations.node01` s'évalue de
# façon autonome ET pour la VM en fonctionnement. Ils sont enveloppés dans
# `lib.mkDefault` pour que le build de l'image Proxmox (tâche ultérieure)
# puisse les surcharger proprement. Les valeurs sont délibérément alignées
# avec l'image : racine par label "nixos" (ext4) sur le disque /dev/sda —
# ce sont des défauts d'infra délibérés, à faire correspondre à l'image
# Proxmox, pas des placeholders d'identité type vars.nix.
{ modulesPath, lib, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = lib.mkDefault [ "/dev/sda" ];
  boot.growPartition = true;
  services.qemuGuest.enable = true;

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
