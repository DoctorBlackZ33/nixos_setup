# A command-line user with no graphical needs.
{ ... }:
{
  fish.enable = true;
  git.enable = true;
  gh.enable = true;
  direnv.enable = true;
  direnv.settings.global.warn_timeout = "30s";
  yazi.enable = true;
  zoxide.enable = true;
}
