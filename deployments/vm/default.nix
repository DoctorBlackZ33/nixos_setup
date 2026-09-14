{ config, inputs, ... }:

let
  modules = config.flake.modules.nixos;
  blackSession = { pkgs, ... }:
    {
      services.greetd.settings.default_session = {
        user = "black";
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
      };
    };
in {
  flake.nixosConfigurations.nixos-dev = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      modules.host-vm
      modules.user-black-account
      blackSession
      modules.kernel-stock
    ];
  };

  flake.nixosConfigurations.nixos-dev-cachy = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      modules.host-vm
      modules.user-black-account
      blackSession
      modules.kernel-cachy
    ];
  };
}
