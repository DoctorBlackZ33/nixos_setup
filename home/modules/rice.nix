{
  config,
  homeContext,
  ...
}: let
  liveRice = path:
    config.lib.file.mkOutOfStoreSymlink "${homeContext.rice.sourceRoot}/${path}";

  riceFile = path: {
    source =
      if homeContext.rice.devMode
      then liveRice path
      else ../../${path};
  };
in {
  home.file.".config/waybar/config" = riceFile "rice/waybar/config";
  home.file.".config/waybar/style.css" = riceFile "rice/waybar/style.css";
  home.file.".config/mako/config" = riceFile "rice/mako/config";
  home.file.".config/fuzzel/fuzzel.ini" = riceFile "rice/fuzzel/fuzzel.ini";
}
