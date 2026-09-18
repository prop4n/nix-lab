{ ... }:
{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = false;

  # Déclaré maintenant, valeur réelle posée au Plan 2.
  sops.secrets."headscale/preauthkey" = { };
}
