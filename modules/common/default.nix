{ lib, pkgs, vars, ... }:
{
  imports = [ ./comin.nix ./sops.nix ./tailnet-client.nix ];

  time.timeZone = vars.timeZone;
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };

  environment.systemPackages = with pkgs; [ git vim curl ];

  # VM serveur headless : pas de docs Info/man (allège l'image et évite la
  # génération du répertoire Info `dir` par buildEnv, cassée dans cet env).
  documentation.info.enable = false;

  users.mutableUsers = false;
  users.users.${vars.adminUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ vars.adminSshKey ];
  };
  security.sudo.wheelNeedsPassword = false;

  # Mot de passe root pour la console (filet de secours si le SSH est HS).
  # null = verrouille. Cf. vars.rootHashedPassword.
  users.users.root.hashedPassword = vars.rootHashedPassword;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  networking.firewall.enable = true;
  networking.nftables.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "26.05";
}
