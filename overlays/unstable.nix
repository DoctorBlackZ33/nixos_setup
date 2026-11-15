# `pkgs.unstable.<name>`: single packages from nixos-unstable. Every host stays
# on the one stable nixpkgs; a workstation profile that needs something newer
# asks for exactly that package.
unstable: final: prev: {
  unstable = import unstable {
    inherit (prev.stdenv.hostPlatform) system;
    inherit (prev) config;
  };
}
