{
  config,
  lib,
  ...
}: {
  options.rice = {
    devMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use live repository rice files instead of store-backed copies.";
    };

    sourceRoot = lib.mkOption {
      type = lib.types.str;
      default = "/home/black/nixos-system";
      description = "Repository or worktree root used for live rice files.";
    };
  };

  config = lib.mkIf config.rice.devMode {
    environment.sessionVariables.RICE_DEV_MODE = "1";
  };
}
