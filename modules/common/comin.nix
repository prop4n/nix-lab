{ vars, ... }:
{
  services.comin = {
    enable = true;
    remotes = [{
      name = "origin";
      url = "https://github.com/${vars.githubOwner}/${vars.githubRepo}.git";
      branches.main.name = "main";
    }];
  };
}
