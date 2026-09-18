# Homelab NixOS + comin

Homelab 100% GitOps : chaque machine embarque **comin**, poll la branche `main`
de ce dépôt et se redéploie seule (`nixos-rebuild switch`). Provisionner une VM
et la laisser rejoindre la flotte est « clé en main ».

Plan 1 (ce dépôt aujourd'hui) : la fondation GitOps + une VM interne `node01`.
Le tailnet (Headscale) et l'edge exposée arrivent au **Plan 2**.

## Architecture (Plan 1)

- **Flake unique** : `nixosConfigurations.node01` = `modules/common` (base durcie,
  comin, sops, client tailscale) + `hosts/node01`.
- **Images par nœud** : chaque hôte a sa propre image Proxmox
  (`packages.x86_64-linux.image-<hôte>`), avec son identité (`services.comin.hostname`)
  **bakée au build** — c'est comin qui, à partir de ce hostname figé, sait quelle
  config déployer. Une image générique unique ne marcherait pas (comin fige sa
  cible au build, pas au runtime).
- **cloud-init** n'injecte QUE le secret d'amorçage : la clé age privée de l'hôte
  (`/var/lib/sops-nix/key.txt`). Pas de hostname (déjà baké).
- **Secrets** : sops-nix, chiffrement age, une clé par hôte.

## Prérequis

1. Remplacer tous les `CHANGEME_*` :
   - `vars.nix` : `domain`, `githubOwner`, `githubRepo`, `adminSshKey`.
   - `.sops.yaml` : clés publiques age (déjà renseignées si générées via Task 4).
   - `tofu/proxmox/terraform.tfvars` (copié depuis `.example`).
2. Pousser ce dépôt sur `github.com/<githubOwner>/<githubRepo>` (public), branche `main`.
3. Token API Proxmox (`root@pam!tofu=…`) avec droits VM.Allocate / Datastore.
4. `nix` (avec flakes), `terraform`/`tofu`, `age`, `sops` disponibles côté opérateur.

## 1. Build + import de l'image de node01

```bash
nix build .#packages.x86_64-linux.image-node01
# le résultat est un backup VMA (format nixos-generators "proxmox") dans result/
scp result/*.vma.zst root@<PVE>:/var/lib/vz/dump/
# sur le PVE : restaurer sous un VMID de template (ex 9001) puis marquer template
ssh root@<PVE> 'qmrestore /var/lib/vz/dump/*.vma.zst 9001 && qm template 9001'
```

> ⚠️ **Alignement filesystem à vérifier au 1er build réel.** `hosts/node01/hardware.nix`
> déclare (en `lib.mkDefault`) un root `fileSystems."/"` par label `nixos` (ext4) et
> `boot.loader.grub.devices = [ "/dev/sda" ]`. Le format nixos-generators `proxmox`
> définit son propre layout : vérifie que le root de l'image tombe bien sur un
> disque vu comme `/dev/sda` avec un label `nixos` ext4 — sinon la VM ne rebootera
> pas après le premier switch comin. Ajuste `hardware.nix` (ou le layout de l'image)
> pour qu'ils correspondent.

## 2. Provisionner node01

```bash
cp tofu/proxmox/terraform.tfvars.example tofu/proxmox/terraform.tfvars
# éditer : pve_endpoint, pve_api_token, pve_node, template_id=9001,
#          node01_age_key = contenu de keys/node01.age (clé PRIVÉE de node01)
cd tofu/proxmox
terraform init      # ou : tofu init
terraform apply     # ou : tofu apply
```

`terraform apply` clone le template `image-node01` en VM `node01` sur `vmbr0` et
injecte la clé age via cloud-init. Aucune action manuelle ensuite.

## 3. Vérifier la convergence GitOps

```bash
# via la console Proxmox de node01 :
journalctl -u comin -f
```

- La VM boot, cloud-init pose `/var/lib/sops-nix/key.txt`.
- comin poll `main` et rebuild `.#node01`.
- **Test end-to-end** : pousser un commit trivial sur `main` et vérifier qu'il est
  appliqué sans SSH.

## Tests

```bash
# évaluation (rapide) : la config et le test s'instancient sans erreur
nix eval .#nixosConfigurations.node01.config.system.build.toplevel.drvPath
nix eval .#checks.x86_64-linux.node01-boot.drvPath

# test d'intégration VM (nécessite KVM ; sops est neutralisé dans le test) :
nix build .#checks.x86_64-linux.node01-boot -L
```

## Notes importantes

- **Le tailnet ne joint pas encore** : `services.tailscale` est câblé vers
  `headscale.<domain>`, mais Headscale n'existe qu'au Plan 2. C'est normal.
- **Sauvegarde `keys/admin.age`** (clé privée age de l'admin) hors-ligne : c'est
  la seule copie ; la perdre = devoir re-chiffrer les secrets avec de nouveaux
  recipients. `keys/` est gitignoré, jamais poussé.
- **Ajouter un nœud** : créer `hosts/<nom>/`, l'ajouter à
  `nixosConfigurations`, générer sa clé age + recipient dans `.sops.yaml`, ajouter
  `packages.image-<nom> = mkProxmoxImage "<nom>"`, build+import une fois, puis
  `terraform apply`.

## Suite — Plan 2 (edge exposée)

Headscale + Headscale-UI, Pangolin/Traefik/ACME Cloudflare, durcissement maximal
(kernel hardened + fallback, AppArmor, CrowdSec, 2FA), bridge DMZ + nftables,
join tailnet de toute la flotte. Voir
`docs/superpowers/specs/2026-09-18-homelab-nixos-comin-design.md`.
