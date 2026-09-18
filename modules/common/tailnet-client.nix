{ config, vars, ... }:
{
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."headscale/preauthkey".path;
    extraUpFlags = [ "--login-server=https://headscale.${vars.domain}" ];
  };
  # Le join effectif se fait quand Headscale existe (Plan 2).
}
