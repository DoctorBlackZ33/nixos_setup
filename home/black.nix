{...}: {
  imports = [
    ./modules/defaults.nix
    ./modules/desktop.nix
    ./modules/yazi.nix
    ./modules/zoxide.nix
    ./modules/gh.nix
    ./modules/lazygit.nix
    ./overrides/black.nix
  ];

  home.username = "black";
  home.homeDirectory = "/home/black";
  home.stateVersion = "26.05";
}
