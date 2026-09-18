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
