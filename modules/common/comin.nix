{ pkgs, inputs, vars, ... }:
let
  # comin 0.14.0 exige Go >= 1.25 (go.mod), mais nixpkgs 25.05 compile par
  # défaut en Go 1.24 -> le build des go-modules échoue. On recompile donc
  # comin avec go_1_25 (présent dans nixpkgs 25.05). Le vendorHash est
  # inchangé (il dépend des sources des modules, pas de la version de Go).
  comin125 = inputs.comin.packages.${pkgs.system}.default.override {
    buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_25; };
  };
in
{
  services.comin = {
    enable = true;
    package = comin125;
    remotes = [{
      name = "origin";
      url = "https://github.com/${vars.githubOwner}/${vars.githubRepo}.git";
      branches.main.name = "main";
    }];
  };
}
