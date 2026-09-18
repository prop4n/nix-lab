# Filesystem/boot fournis par le format nixos-generators "proxmox".
# Ce fichier ne redéclare que le strict nécessaire au runtime.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/sda" ]; # placeholder, réel disque fourni par le format proxmox
  boot.growPartition = true;
  services.qemuGuest.enable = true;

  # Placeholder pour satisfaire l'assertion NixOS (root fs requis) ; le
  # partitionnement réel est produit par le format nixos-generators "proxmox".
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
