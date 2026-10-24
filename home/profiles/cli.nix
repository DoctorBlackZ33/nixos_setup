{ pkgs, ... }:

{
  myHome.nvf.enable = true;

  home.packages = with pkgs; [
    bashInteractive
    btop
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.git.settings.init.defaultBranch = "main";
}
