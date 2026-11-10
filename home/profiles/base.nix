{ pkgs, ... }:

{
  packages = with pkgs; [
    home-manager
    lazygit
  ];

  direnv.enable = true;
  fish.enable = true;
  fish.settings.commandColor = "brcyan";
  fish.settings.aliases = {
    ll = "ls -lah";
    la = "ls -A";
  };
  git.enable = true;
  yazi.enable = true;
  zoxide.enable = true;
}
