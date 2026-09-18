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

  networking.firewall.enable = true;
  networking.nftables.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.05";
}
