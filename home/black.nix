{...}: {
  imports = [
    ./modules/defaults.nix
    ./modules/desktop.nix
    ./modules/gh.nix
    ./overrides/black.nix
  ];

  home.username = "black";
  home.homeDirectory = "/home/black";
  home.stateVersion = "26.05";
}
