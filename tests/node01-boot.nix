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
    #
    # Adaptation vs. le brief : `sops.secrets = lib.mkForce { };` (vider tout
    # l'attrset) casse l'évaluation. `modules/common/tailnet-client.nix`
    # référence en dur `config.sops.secrets."headscale/preauthkey".path` ;
    # le système de modules "discharge" (déballe mkIf/mkMerge/mkOverride)
    # TOUTES les définitions candidates d'une option — y compris celles
    # perdantes en priorité — avant de filtrer par priorité. Vider
    # `sops.secrets` fait donc disparaître la clé "headscale/preauthkey"
    # AVANT que le mkForce sur `services.tailscale.authKeyFile` ne puisse
    # écarter la définition perdante de tailnet-client.nix, d'où une erreur
    # "attribute missing" au lieu d'un warning silencieux. On neutralise donc
    # secret par secret : la clé "headscale/preauthkey" reste déclarée (son
    # `.path` reste toujours résolvable) mais son `path` est forcé vers
    # /dev/null, et `authKeyFile` est forcé de la même façon.
    sops.secrets."headscale/preauthkey".path = lib.mkForce "/dev/null";
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
