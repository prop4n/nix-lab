# Homelab NixOS + comin — GitOps, edge durcie

**Date** : 2026-09-18
**Statut** : design validé, prêt pour le plan d'implémentation

## 1. Objectif

Homelab 100% GitOps : un seul dépôt GitHub public décrit toutes les machines
NixOS. Chaque machine embarque **comin**, poll la branche `main` et se
redéploie seule (`nixos-rebuild switch`) — aucun `ssh` ni push manuel pour
converger. Provisionner une VM et la laisser rejoindre la flotte doit être
« clé en main ».

Tout tourne sur **Proxmox** (x86_64). Une VM **edge** exposée à Internet via un
port-forward de la box maison héberge l'ingress public ; les autres VMs sont
internes et clientes du tailnet.

### Services jour 1 (on commence soft)
- **edge** : Pangolin (reverse-proxy tunnelé) + Headscale (control plane
  tailnet) + Headscale-UI.
- **node01** : VM NixOS minimale, jointe au tailnet, SSH via tailnet. Sert à
  valider le pipeline GitOps de bout en bout avant d'ajouter des services.

### Non-objectifs (YAGNI)
- Pas d'Oracle / aarch64 (abandonné : tout est Proxmox x86).
- Pas de services applicatifs au-delà de la base + edge au jour 1.
- Pas de HA/clustering Headscale, pas de monitoring lourd pour l'instant.

## 2. Topologie

```
Internet
   │  (port-forward box : 443/tcp, 51820/udp UNIQUEMENT)
   ▼
┌─────────────────────────────────────────────┐
│ Proxmox                                       │
│                                               │
│  bridge vmbr1 (DMZ, isolé du LAN par nftables)│
│   └── VM edge  ── Traefik :443 (wildcard TLS) │
│        ├── Pangolin (dashboard + gerbil WG)   │
│        ├── Headscale        (LAN/tailnet only)│
│        └── Headscale-UI     (LAN/tailnet only)│
│                                               │
│  bridge vmbr0 (LAN interne)                   │
│   └── VM node01 ── tailscale client ──────────┼──▶ join Headscale (via LAN)
│        (+ futures VMs)                         │
└─────────────────────────────────────────────┘

Ingress public  : Internet → Traefik(edge) → newt/gerbil → service interne
Mesh/admin       : toutes les VMs sur le tailnet Headscale (SSH, gestion)
```

L'edge ne peut **pas** initier de connexion vers le LAN interne (nftables).
Les VMs internes joignent Headscale via le LAN ; Headscale n'est jamais exposé
publiquement au jour 1.

## 3. Structure du dépôt

```
flake.nix / flake.lock
.sops.yaml
hosts/
  edge/       default.nix, hardware.nix (disko), networking.nix
  node01/     default.nix, hardware.nix
modules/
  common/     users, ssh (tailnet-only), nix settings, comin, sops, tailscale-client
  edge/       headscale.nix, headscale-ui.nix, pangolin.nix, traefik-acme.nix,
              hardening.nix, firewall.nix
secrets/
  secrets.yaml   (sops : preauthkey headscale, token Cloudflare DNS, 2FA seeds)
images/
  proxmox-template.nix   (nixos-generators : image + comin baké + cloud-init)
tofu/
  proxmox/    (bpg/proxmox : clone template → VMs, cloud-init hostname + clé age)
docs/superpowers/specs/
```

## 4. Modèle GitOps (comin)

- `services.comin` sur chaque host : `remotes = [{ name="origin";
  url="https://github.com/<user>/<repo>"; branches.main.name="main"; }]`,
  poller activé.
- comin construit la sortie `nixosConfigurations.<hostname>` correspondant au
  hostname de la machine (fixé par cloud-init).
- Push sur `main` → convergence automatique de toute la flotte.
- Auto-update des dépendances : bump régulier de `flake.lock` (commit → comin
  déploie). Reboots kernel gérés par une fenêtre de reboot contrôlée.

## 5. Bootstrap & provisioning

Séparation stricte : **image = code**, **cloud-init = identité + secret d'amorçage**.

1. **Build du template Proxmox** : `nixos-generators` produit une image x86_64
   avec comin + cloud-init bakés, importée dans Proxmox comme template.
2. **`tofu apply`** (provider `bpg/proxmox`) clone le template en VMs et injecte
   via cloud-init : le **hostname** (→ sélectionne la conf) et la **clé age
   privée** du host (→ déchiffre sops). Aucune action manuelle post-apply.
3. La VM boot → comin pull `main` → build `.#<hostname>` → tailscale join.
4. **edge** placée sur `vmbr1`, les VMs internes sur `vmbr0` (via tofu).

## 6. Services edge

- **Traefik** (fourni avec la stack Pangolin) possède `:80/:443`, termine le TLS
  avec un **certificat wildcard `*.<domaine>` via ACME DNS-01 Cloudflare**
  (token dans sops). Seul lui est joignable publiquement.
- **Pangolin** (dashboard + gateway WireGuard `gerbil` + agent `newt` côté
  interne) tourne en conteneurs via `virtualisation.oci-containers` (backend
  **podman**) — pas de module NixOS natif.
- **Headscale** : module natif `services.headscale`, bind LAN/tailnet only,
  TLS interne via le wildcard. **ACLs** Headscale restrictives (voir §8).
- **Headscale-UI** : servie derrière Traefik sur un entrypoint LAN-only,
  jamais forwardée.

## 7. Tailnet & flux de join

- VMs internes : `services.tailscale` avec `--login-server
  https://headscale.<domaine>` (résolu en interne) + **pre-auth key réutilisable**
  (sops) → join auto au boot.
- **Une seule action de bootstrap** : à la 1ʳᵉ montée de l'edge, créer une
  reusable preauthkey (`headscale preauthkeys create --reusable`), la chiffrer
  dans `secrets/secrets.yaml`, push. Ensuite tout join est automatique.

## 8. Secrets

- **sops-nix**, chiffrement **age**, **une clé par host** : clé publique dans
  `.sops.yaml`, clé privée injectée par cloud-init à l'instanciation (jamais
  dans le repo, jamais dans l'image).
- Secrets gérés : preauthkey Headscale, token API Cloudflare (ACME DNS-01),
  seeds 2FA du dashboard, éventuels tokens Pangolin.

## 9. Durcissement de l'edge (niveau maximal)

Machine à plus haute valeur (control plane + exposée). Mesures :

**Réseau**
- Bridge dédié `vmbr1` ; **nftables deny-by-default** ; edge→LAN interdit.
- Surface publique = `443/tcp` (Traefik) + `51820/udp` (gerbil) **uniquement**.
- Aucun SSH public : `services.openssh` bind sur l'IP tailnet seulement,
  keys-only, `PermitRootLogin no`, pas de mot de passe. Console de secours =
  Proxmox.

**Système**
- **Kernel hardened** (`boot.kernelPackages = linuxPackages_hardened`).
  ⚠️ Risque de casse des conteneurs Pangolin : si échec au boot, on bascule le
  kernel standard en **conservant tout le reste**. Décision documentée, testée
  au premier déploiement.
- **AppArmor** activé.
- **CrowdSec** + bouncer Traefik : ban automatique des IP malveillantes sur
  l'ingress public.
- **2FA** sur le dashboard Pangolin et l'accès Headscale-UI.
- Sandboxing systemd (`ProtectSystem`, `ProtectHome`, `NoNewPrivileges`,
  `PrivateTmp`, capabilities minimales) sur les services et le runtime podman.
- **podman** (préféré à docker : pas de manipulation d'iptables parasite,
  rootless quand possible ; caps explicites pour gerbil/Traefik).
- `auditd` + journald persistant ; durcissement sysctl.

**Tailnet**
- **ACLs Headscale** : segmentation stricte pour qu'un nœud compromis (edge
  incluse) ne puisse pas atteindre tout le tailnet — limite le rayon de souffle.

## 10. Ordre de déploiement

1. Build template + `tofu apply` de l'edge (sur `vmbr1`).
2. edge monte : Headscale + Pangolin + Traefik up.
3. Action bootstrap : preauthkey → sops → push.
4. Port-forward box : `443/tcp` + `51820/udp` → edge.
5. DNS Cloudflare : `A <domaine>` + `*.<domaine>` → IP publique maison.
6. `tofu apply` de node01 (sur `vmbr0`) → join auto du tailnet.

## 11. Placeholders à renseigner

- Domaine public (`<domaine>`).
- Compte/repo GitHub (`<user>/<repo>`).
- Endpoint + credentials API Proxmox (pour OpenTofu).
- Token API Cloudflare (scope DNS edit sur la zone).
- Plage IP LAN / DMZ, IP publique maison.

## 12. Risques & points ouverts

- **Kernel hardened vs conteneurs Pangolin** : arbitrage à valider au 1ᵉʳ boot
  (fallback prévu).
- **IP résidentielle exposée** : accepté par l'utilisateur ; CrowdSec + surface
  minimale + isolation DMZ atténuent.
- **Bootstrap preauthkey** : une action manuelle unique assumée.
- **Pangolin sur NixOS** : déployé en conteneurs (upstream = docker-compose),
  à transposer proprement en `oci-containers` podman.
