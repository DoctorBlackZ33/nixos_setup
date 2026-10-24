{ pkgs, ... }:

{
  programs.fish.enable = true;

  users.users.admin = {
    isNormalUser = true;
    description = "Administrator";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    # Bootstrap credential only. With mutable users, passwd persists on rebuild.
    initialHashedPassword = "$6$IMSbi9DiWzYi2nZW$H9fTRCl9YP67FYnKjhprbnutpRT6PgGYWgI2MGGDWmss95EhxqoZL4xTPTPDyR9UFUTqW28a3FGcl7XVTJty50";
  };
}
