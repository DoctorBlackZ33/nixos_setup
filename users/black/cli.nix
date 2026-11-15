# Shell baseline, on every host.
{ pkgs, ... }:
{
  packages = [ pkgs.btop ];

  fish = {
    enable = true;
    commandColor = "brcyan";
    aliases = {
      ll = "ls -lah";
      la = "ls -A";
    };
  };

  git = {
    enable = true;
    settings = {
      user.name = "DoctorBlack Z 33";
      user.email = "72605982+DoctorBlackZ33@users.noreply.github.com";
      init.defaultBranch = "main";
    };
  };

  yazi = {
    enable = true;
    fishKey = "ctrl-x";
    settings.mgr = {
      show_hidden = true;
      sort_by = "natural";
      sort_dir_first = true;
    };
  };

  zoxide = {
    enable = true;
    # Replace `cd` itself.
    flags = [ "--cmd=cd" ];
  };
}
