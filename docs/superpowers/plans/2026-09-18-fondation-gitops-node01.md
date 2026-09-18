# Plan 1 — Fondation GitOps + node01

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Poser le socle GitOps : un flake NixOS que comin déploie tout seul sur une VM Proxmox interne (`node01`), provisionnée par une image pré-construite + OpenTofu, avec secrets sops-nix par host.

**Architecture:** Un flake unique définit `nixosConfigurations.node01` (= module commun + host). L'image Proxmox est générée par nixos-generators avec comin + cloud-init bakés. OpenTofu (`bpg/proxmox`) clone le template et injecte via cloud-init le hostname + la clé age privée du host. Au boot, comin poll `main` et rebuild `.#<hostname>`. Le tailnet est câblé mais ne joint qu'au Plan 2 (Headscale n'existe pas encore).

**Tech Stack:** Nix flakes, NixOS 25.05 (x86_64-linux), comin, sops-nix (age), nixos-generators (format `proxmox`), OpenTofu + provider `bpg/proxmox`, cloud-init.

## Global Constraints

- nixpkgs : `github:NixOS/nixpkgs/nixos-25.05` — tous les inputs `follows` dessus.
- Système cible unique : `x86_64-linux`.
- Flakes + `nix-command` requis (`--extra-experimental-features "nix-command flakes"` si non global).
- comin poll la branche `main` du repo GitHub public `github:CHANGEME_USER/CHANGEME_REPO`.
- Secrets : sops-nix, chiffrement age, **une clé par host**, clé privée à `/var/lib/sops-nix/key.txt` (posée par cloud-init). Fichier chiffré unique : `secrets/secrets.yaml`.
- SSH : keys-only, `PermitRootLogin no`, pas de mot de passe. Utilisateur admin : `deploy`.
- Firewall : `networking.nftables.enable = true`, deny-by-default. node01 : seul `22/tcp` ouvert (sera restreint au tailnet au Plan 2).
- Pas de disko (le layout disque vient du format nixos-generators `proxmox`).
- Placeholders explicites, en MAJUSCULES préfixées `CHANGEME_`, centralisés dans `vars.nix`.

---

### Task 1 : Squelette du flake + node01 buildable

**Files:**
- Create: `flake.nix`
- Create: `vars.nix`
- Create: `hosts/node01/default.nix`
- Create: `hosts/node01/hardware.nix`
- Create: `modules/common/default.nix`
- Create: `.gitignore`

**Interfaces:**
- Produces: `nixosConfigurations.node01` ; helper `mkHost :: hostName -> [module] -> nixosSystem` ; `vars` (attrset) via `specialArgs`.

- [ ] **Step 1 : Écrire `.gitignore`**

```gitignore
result
result-*
.direnv/
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
# clés privées — ne JAMAIS committer
*.age
keys/
```

- [ ] **Step 2 : Écrire `vars.nix` (placeholders centralisés)**

```nix
{
  domain = "CHANGEME_DOMAIN";              # ex: lab.example.com
  githubOwner = "CHANGEME_USER";
  githubRepo = "CHANGEME_REPO";
  adminUser = "deploy";
  # clé publique SSH de l'admin (remplacer)
  adminSshKey = "ssh-ed25519 AAAA_CHANGEME admin";
  timeZone = "Europe/Paris";
}
```

- [ ] **Step 3 : Écrire `modules/common/default.nix` (stub minimal buildable)**

```nix
{ lib, pkgs, vars, ... }:
{
  imports = [ ];

  time.timeZone = vars.timeZone;
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };

  environment.systemPackages = with pkgs; [ git vim curl ];

  system.stateVersion = "25.05";
}
```

- [ ] **Step 4 : Écrire `hosts/node01/hardware.nix`**

```nix
# Filesystem/boot fournis par le format nixos-generators "proxmox".
# Ce fichier ne redéclare que le strict nécessaire au runtime.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub.enable = true;
  boot.growPartition = true;
  services.qemuGuest.enable = true;
}
```

- [ ] **Step 5 : Écrire `hosts/node01/default.nix`**

```nix
{ vars, ... }:
{
  imports = [ ./hardware.nix ];
  networking.hostName = "node01";
  networking.useDHCP = true;
}
```

- [ ] **Step 6 : Écrire `flake.nix`**

```nix
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
    };
}
```

- [ ] **Step 7 : Vérifier le build (le "test")**

Run: `nix build .#nixosConfigurations.node01.config.system.build.toplevel --extra-experimental-features "nix-command flakes"`
Expected: succès, un lien `result` est créé. (Corriger toute erreur d'évaluation avant de continuer.)

- [ ] **Step 8 : Committer**

```bash
git add flake.nix flake.lock vars.nix hosts modules .gitignore
git commit -m "feat: squelette flake + node01 buildable"
```

---

### Task 2 : Module commun — utilisateur admin, SSH keys-only, firewall

**Files:**
- Modify: `modules/common/default.nix`

**Interfaces:**
- Consumes: `vars.adminUser`, `vars.adminSshKey`.
- Produces: utilisateur `deploy` (wheel, sudo sans mot de passe), `sshd` keys-only, nftables deny-by-default.

- [ ] **Step 1 : Ajouter utilisateur admin + SSH durci dans `modules/common/default.nix`**

Ajouter au corps du module :

```nix
  users.mutableUsers = false;
  users.users.${vars.adminUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ vars.adminSshKey ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
```

- [ ] **Step 2 : Activer nftables deny-by-default + ouvrir 22/tcp**

Ajouter :

```nix
  networking.firewall.enable = true;
  networking.nftables.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
```

- [ ] **Step 3 : Vérifier le build**

Run: `nix build .#nixosConfigurations.node01.config.system.build.toplevel`
Expected: succès.

- [ ] **Step 4 : Committer**

```bash
git add modules/common/default.nix
git commit -m "feat(common): admin deploy + ssh keys-only + nftables deny-default"
```

---

### Task 3 : Module comin (GitOps)

**Files:**
- Create: `modules/common/comin.nix`
- Modify: `modules/common/default.nix` (import)

**Interfaces:**
- Consumes: `vars.githubOwner`, `vars.githubRepo`.
- Produces: `services.comin` actif, poll `main` du repo public.

- [ ] **Step 1 : Écrire `modules/common/comin.nix`**

```nix
{ vars, ... }:
{
  services.comin = {
    enable = true;
    remotes = [{
      name = "origin";
      url = "https://github.com/${vars.githubOwner}/${vars.githubRepo}.git";
      branches.main.name = "main";
    }];
  };
}
```

- [ ] **Step 2 : Importer dans `modules/common/default.nix`**

Dans `imports = [ ]`, mettre :

```nix
  imports = [ ./comin.nix ];
```

- [ ] **Step 3 : Vérifier le build + que le service est déclaré**

Run: `nix build .#nixosConfigurations.node01.config.system.build.toplevel`
Puis: `nix eval .#nixosConfigurations.node01.config.services.comin.enable`
Expected: build OK, `true`.

- [ ] **Step 4 : Committer**

```bash
git add modules/common/comin.nix modules/common/default.nix
git commit -m "feat(common): comin GitOps sur branche main"
```

---

### Task 4 : sops-nix + génération des clés age + secrets.yaml

**Files:**
- Create: `modules/common/sops.nix`
- Create: `.sops.yaml`
- Create: `secrets/secrets.yaml` (chiffré)
- Modify: `modules/common/default.nix` (import)

**Interfaces:**
- Consumes: clé age privée du host à `/var/lib/sops-nix/key.txt` (posée par cloud-init, Task 6/7).
- Produces: `sops.defaultSopsFile` = `secrets/secrets.yaml` ; secret `headscale/preauthkey` déclaré (placeholder tant que le Plan 2 ne l'a pas créé).

- [ ] **Step 1 : Installer age + sops (environnement de dev)**

Run: `nix shell nixpkgs#age nixpkgs#sops`
(Rester dans ce shell pour les steps suivants.)

- [ ] **Step 2 : Générer une clé age pour node01 et pour l'admin**

```bash
mkdir -p keys
age-keygen -o keys/node01.age 2>/dev/null
age-keygen -o keys/admin.age 2>/dev/null
NODE01_PUB=$(age-keygen -y keys/node01.age)
ADMIN_PUB=$(age-keygen -y keys/admin.age)
echo "node01=$NODE01_PUB"; echo "admin=$ADMIN_PUB"
```
> ⚠️ `keys/` est gitignoré. `keys/node01.age` sera injecté par cloud-init sur la VM (Task 7). `keys/admin.age` reste sur ta machine pour éditer les secrets.

- [ ] **Step 3 : Écrire `.sops.yaml` (recipients)**

Remplacer les valeurs par les clés publiques du step 2 :

```yaml
keys:
  - &admin CHANGEME_ADMIN_AGE_PUB
  - &node01 CHANGEME_NODE01_AGE_PUB
creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *admin
          - *node01
```

- [ ] **Step 4 : Créer `secrets/secrets.yaml` avec un placeholder chiffré**

```bash
mkdir -p secrets
SOPS_AGE_KEY_FILE=keys/admin.age sops --config .sops.yaml \
  set secrets/secrets.yaml '["headscale"]["preauthkey"]' '"PLACEHOLDER_A_REMPLACER_PLAN2"'
```
Vérifier qu'il est bien chiffré :
Run: `grep -q "ENC\[" secrets/secrets.yaml && echo CHIFFRE`
Expected: `CHIFFRE`.

- [ ] **Step 5 : Écrire `modules/common/sops.nix`**

```nix
{ ... }:
{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = false;

  # Déclaré maintenant, valeur réelle posée au Plan 2.
  sops.secrets."headscale/preauthkey" = { };
}
```

- [ ] **Step 6 : Importer dans `modules/common/default.nix`**

```nix
  imports = [ ./comin.nix ./sops.nix ];
```

- [ ] **Step 7 : Vérifier le build (la déchiffrement n'a lieu qu'à l'activation, pas au build)**

Run: `nix build .#nixosConfigurations.node01.config.system.build.toplevel`
Expected: succès.

- [ ] **Step 8 : Committer (les clés privées restent hors du repo)**

```bash
git add .sops.yaml secrets/secrets.yaml modules/common/sops.nix modules/common/default.nix
git commit -m "feat(common): sops-nix + secret preauthkey (placeholder)"
```

---

### Task 5 : Client tailscale (câblé, join au Plan 2)

**Files:**
- Create: `modules/common/tailnet-client.nix`
- Modify: `modules/common/default.nix` (import)

**Interfaces:**
- Consumes: secret `headscale/preauthkey`, `vars.domain`.
- Produces: `services.tailscale` activé, `authKeyFile` = secret sops, `--login-server` vers `headscale.<domain>`.

- [ ] **Step 1 : Écrire `modules/common/tailnet-client.nix`**

```nix
{ config, vars, ... }:
{
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."headscale/preauthkey".path;
    extraUpFlags = [ "--login-server=https://headscale.${vars.domain}" ];
  };
  # Le join effectif se fait quand Headscale existe (Plan 2).
}
```

- [ ] **Step 2 : Importer dans `modules/common/default.nix`**

```nix
  imports = [ ./comin.nix ./sops.nix ./tailnet-client.nix ];
```

- [ ] **Step 3 : Vérifier le build**

Run: `nix build .#nixosConfigurations.node01.config.system.build.toplevel`
Expected: succès.

- [ ] **Step 4 : Committer**

```bash
git add modules/common/tailnet-client.nix modules/common/default.nix
git commit -m "feat(common): client tailscale vers headscale (join au Plan 2)"
```

---

### Task 6 : Image template Proxmox (nixos-generators + cloud-init)

**Files:**
- Create: `images/proxmox-template.nix`
- Modify: `flake.nix` (sortie `packages.proxmox-template`)

**Interfaces:**
- Consumes: `modules/common` (donc comin + sops + tailscale), `vars`.
- Produces: `packages.x86_64-linux.proxmox-template` (image `.vma.zst` importable). cloud-init activé pour recevoir hostname + clé age.

- [ ] **Step 1 : Écrire `images/proxmox-template.nix`**

```nix
# Image générique : comin + cloud-init bakés, PAS de hostname ni de secret.
# cloud-init (via OpenTofu) posera le hostname et /var/lib/sops-nix/key.txt.
{ modulesPath, ... }:
{
  imports = [
    ../modules/common
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  services.cloud-init = {
    enable = true;
    network.enable = true;
  };
  # cloud-init écrit la clé age et fixe le hostname au 1er boot.
  boot.growPartition = true;
  boot.loader.grub.enable = true;
}
```

- [ ] **Step 2 : Ajouter la sortie image dans `flake.nix`**

Dans le `let`, après `pkgs = ...`, garder. Dans l'attrset de sortie, ajouter à côté de `nixosConfigurations` :

```nix
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
```

- [ ] **Step 3 : Vérifier que l'image évalue (build long : optionnel en CI, obligatoire avant import réel)**

Run: `nix build .#packages.x86_64-linux.proxmox-template --dry-run`
Expected: pas d'erreur d'évaluation (liste des dérivations à construire).

- [ ] **Step 4 : Committer**

```bash
git add images/proxmox-template.nix flake.nix
git commit -m "feat(image): template Proxmox nixos-generators + cloud-init"
```

---

### Task 7 : Provisioning OpenTofu (bpg/proxmox)

**Files:**
- Create: `tofu/proxmox/main.tf`
- Create: `tofu/proxmox/variables.tf`
- Create: `tofu/proxmox/terraform.tfvars.example`
- Create: `tofu/proxmox/cloud-init-node01.yaml.tftpl`

**Interfaces:**
- Consumes: template importé dans Proxmox (`var.template_id`), `keys/node01.age`.
- Produces: VM `node01` sur `vmbr0` avec cloud-init (hostname + clé age).

- [ ] **Step 1 : Écrire `tofu/proxmox/variables.tf`**

```hcl
variable "pve_endpoint"  { type = string }              # https://pve.lan:8006/
variable "pve_api_token" { type = string, sensitive = true }
variable "pve_node"      { type = string }              # ex: pve
variable "template_id"   { type = number }              # VMID du template importé
variable "node01_age_key" { type = string, sensitive = true } # contenu de keys/node01.age
```

- [ ] **Step 2 : Écrire `tofu/proxmox/cloud-init-node01.yaml.tftpl`**

```yaml
#cloud-config
hostname: node01
write_files:
  - path: /var/lib/sops-nix/key.txt
    permissions: "0600"
    owner: root:root
    content: |
      ${indent(6, age_key)}
```

- [ ] **Step 3 : Écrire `tofu/proxmox/main.tf`**

```hcl
terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox", version = "~> 0.66" }
  }
}

provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token
  insecure  = true
}

resource "proxmox_virtual_environment_file" "node01_ci" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.pve_node
  source_raw {
    file_name = "cloud-init-node01.yaml"
    data      = templatefile("${path.module}/cloud-init-node01.yaml.tftpl", {
      age_key = var.node01_age_key
    })
  }
}

resource "proxmox_virtual_environment_vm" "node01" {
  name      = "node01"
  node_name = var.pve_node

  clone { vm_id = var.template_id }

  cpu    { cores = 2 }
  memory { dedicated = 2048 }

  agent { enabled = true }

  network_device { bridge = "vmbr0" }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.node01_ci.id
    ip_config { ipv4 { address = "dhcp" } }
  }
}
```

- [ ] **Step 4 : Écrire `tofu/proxmox/terraform.tfvars.example`**

```hcl
pve_endpoint  = "https://CHANGEME_PVE:8006/"
pve_api_token = "root@pam!tofu=CHANGEME_TOKEN"
pve_node      = "pve"
template_id   = 9000
node01_age_key = "AGE-SECRET-KEY-CHANGEME"
```

- [ ] **Step 5 : Vérifier la syntaxe/validité (sans credentials réels)**

```bash
cd tofu/proxmox
tofu init -backend=false
tofu fmt -check
tofu validate
```
Expected: `Success! The configuration is valid.`

- [ ] **Step 6 : Committer (jamais le vrai tfvars ni la clé)**

```bash
git add tofu/proxmox/main.tf tofu/proxmox/variables.tf \
        tofu/proxmox/terraform.tfvars.example tofu/proxmox/cloud-init-node01.yaml.tftpl
git commit -m "feat(tofu): provisioning node01 sur Proxmox + cloud-init identity"
```

---

### Task 8 : Test d'intégration nixosTest (boot + assertions)

**Files:**
- Create: `tests/node01-boot.nix`
- Modify: `flake.nix` (sortie `checks`)

**Interfaces:**
- Consumes: `modules/common`, `hosts/node01`.
- Produces: `checks.x86_64-linux.node01-boot`. sops est neutralisé dans le test (pas de clé age dans le sandbox).

- [ ] **Step 1 : Écrire `tests/node01-boot.nix`**

```nix
{ pkgs, inputs, vars, ... }:
pkgs.testers.runNixOSTest {
  name = "node01-boot";
  node.specialArgs = { inherit inputs vars; };
  nodes.machine = { lib, ... }: {
    imports = [
      inputs.comin.nixosModules.comin
      inputs.sops-nix.nixosModules.sops
      ../modules/common
      ../hosts/node01
    ];
    # Neutraliser sops (pas de clé age dans le sandbox de test).
    sops.secrets = lib.mkForce { };
    services.tailscale.authKeyFile = lib.mkForce "/dev/null";
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("systemctl is-enabled comin.service")
    machine.succeed("id ${vars.adminUser}")
    machine.succeed("sshd -T | grep -i 'permitrootlogin no'")
    machine.succeed("sshd -T | grep -i 'passwordauthentication no'")
    machine.succeed("systemctl is-enabled tailscaled.service")
  '';
}
```

- [ ] **Step 2 : Ajouter la sortie `checks` dans `flake.nix`**

Dans l'attrset de sortie :

```nix
      checks.${system}.node01-boot =
        import ./tests/node01-boot.nix { inherit pkgs inputs vars; };
```

- [ ] **Step 3 : Lancer le test**

Run: `nix build .#checks.x86_64-linux.node01-boot -L`
Expected: le test boote la VM et toutes les assertions passent (build réussit).

- [ ] **Step 4 : Committer**

```bash
git add tests/node01-boot.nix flake.nix
git commit -m "test: nixosTest boot node01 (comin, ssh durci, tailscaled)"
```

---

### Task 9 : Runbook opérateur (README) — actions sur infra réelle

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: procédure reproductible pour amener node01 en prod. **Ces steps s'exécutent sur ton infra réelle** (Proxmox, GitHub), pas dans le sandbox.

- [ ] **Step 1 : Écrire `README.md` avec le runbook**

Contenu (procédure, pas de code à tester ici) :

```markdown
# Homelab NixOS + comin

## Prérequis
- Remplacer tous les `CHANGEME_*` dans `vars.nix`, `.sops.yaml`, `tofu/proxmox/terraform.tfvars`.
- Repo poussé sur `github.com/<owner>/<repo>` (public), branche `main`.
- Token API Proxmox (`root@pam!tofu`) avec droits VM.Allocate/Datastore.

## 1. Build + import de l'image template
    nix build .#packages.x86_64-linux.proxmox-template
    # copier result/vzdump-*.vma.zst sur le PVE (scp) puis :
    # sur le PVE : qmrestore /chemin/vzdump-*.vma.zst 9000
    # puis marquer 9000 comme template : qm template 9000

## 2. Provisionner node01
    cp tofu/proxmox/terraform.tfvars.example tofu/proxmox/terraform.tfvars
    # renseigner node01_age_key = contenu de keys/node01.age
    cd tofu/proxmox && tofu init && tofu apply

## 3. Vérifier la convergence GitOps
- La VM boot, cloud-init pose hostname=node01 + clé age.
- comin poll `main` et rebuild `.#node01` (voir `journalctl -u comin -f` via console Proxmox).
- Test : pousser un commit trivial sur `main`, vérifier qu'il est appliqué sans SSH.

## Notes
- Le tailnet ne joint qu'au Plan 2 (Headscale pas encore déployé) : c'est normal.
- Clés privées (`keys/`) : hors du repo, à sauvegarder hors-ligne.
```

- [ ] **Step 2 : Committer**

```bash
git add README.md
git commit -m "docs: runbook opérateur node01"
```

---

## Self-Review

- **Couverture spec** : GitOps/comin (T3), structure repo (T1-T8), bootstrap image+cloud-init (T6-T7), tailnet câblé (T5, join reporté Plan 2 comme prévu par le spec §7), secrets sops par-host (T4), provisioning OpenTofu (T7). Durcissement *maximal* et services *edge* (Headscale/Pangolin/Traefik/DMZ) = **Plan 2**, hors scope ici (le spec les situe sur l'edge).
- **Placeholders** : uniquement les `CHANGEME_*` volontaires (valeurs d'infra propres à l'utilisateur), centralisés et documentés dans le runbook. Aucun step de code laissé vide.
- **Cohérence des types** : `vars` (attrset) passé partout via `specialArgs`/paramètres ; `sops.secrets."headscale/preauthkey"` référencé identiquement en T4/T5 ; `packages.x86_64-linux.proxmox-template` / `checks.x86_64-linux.node01-boot` cohérents T6/T8.

## Suite

Plan 2 — **Edge exposée** : Headscale + Headscale-UI, Pangolin/gerbil/newt en oci-containers podman, Traefik + wildcard ACME Cloudflare DNS-01, durcissement maximal (kernel hardened + fallback, AppArmor, CrowdSec, 2FA, sandboxing systemd), bridge DMZ `vmbr1` + nftables edge→LAN, action bootstrap preauthkey, port-forward + DNS. À écrire une fois le Plan 1 exécuté et validé.
