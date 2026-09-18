{ vars, ... }:
{
  imports = [ ./hardware.nix ];
  networking.hostName = "node01";
  networking.useDHCP = true;
}
