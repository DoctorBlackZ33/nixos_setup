# sysMod
## Purpose
These are general purpose nix modules to build a system. These rulse should contain everthing that requires sudo, needs to run user agnostic or contains system functionality that should not be touched by users. 

## Docs
### desktop.nix
Supports and configures basic compositors and supports: Hyprland and Niri. For that support it also configures the xdg-desktop-portal implementations. It also enables audio support via pipewire and adds basic system fonts.

### development.nix
Enables all the default packages needed to start developing and provide basic functionality

### networking.nix
Enables network manager and a basic integrated firewall as well as ssh

### nix-settings.nix
Configures nix garbage collection and store auto omptimization. It also sets some default nix settings and experimental features

### tty.nix
Adds options for time zone and locale if there ever needs to be additional implementation around this. It also adds an option to configure the greeter with current choices: greetd and SDDM

## Plan
- [ ] Add support for the [river](https://codeberg.org/river/river) compositors
- [ ] Replace the basic firewall with a more advanced firewall

