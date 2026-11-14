# userConf for black: profiles, preferences and sources.
{ pkgs, ... }:
{
  imports = [ ./sources.nix ];

  packages = with pkgs; [
    bashInteractive
    btop
    grim
    home-manager
    kitty
    lazygit
    wl-clipboard
  ];

  environment = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  direnv.enable = true;
  fish.enable = true;
  fish.settings.commandColor = "brcyan";
  fish.settings.aliases = {
    ll = "ls -lah";
    la = "ls -A";
  };
  gh.enable = true;
  git.enable = true;
  nvf.enable = true;
  yazi.enable = true;
  zoxide.enable = true;

  git.settings = {
    user.name = "DoctorBlack Z 33";
    user.email = "72605982+DoctorBlackZ33@users.noreply.github.com";
    init.defaultBranch = "main";
  };

  fuzzel.enable = true;
  hyprland.enable = true;
  mako.enable = true;
  quickshell.enable = true;
}
