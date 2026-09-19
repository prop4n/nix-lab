{
  domain = "CHANGEME_DOMAIN";              # ex: lab.example.com — À RENSEIGNER
  githubOwner = "prop4n";
  githubRepo = "nix-lab";
  adminUser = "deploy";
  # clé publique SSH de l'admin (~/.ssh/id_ed25519_homelab.pub)
  adminSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIL1sYJIG6iLyjf+rj5qSinehKfwFdB9Itk4yuTJKOhy propan@guix";
  timeZone = "Europe/Paris";
  # Hash du mot de passe root pour la CONSOLE (mkpasswd -m sha-512).
  # null = root verrouillé (pas de login console). Un hash fort est sûr à
  # publier ; l'accès console = accès Proxmox de toute façon.
  rootHashedPassword = "$6$u3QtvvRqP1rJoDiL$XL8V6VdpGrsvkcvKelT5MQFe9UrmX4gSZm757tr7M8SXuAeqNRu289aUd4O5RCTPXkx42pYzCcaA7TGSDIBV3.";
}
