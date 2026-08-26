{ pkgs, ... }:

{
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.openssh.enable = true;

  users.mutableUsers = false;
  users.users.black = {
    isNormalUser = true;
    description = "Black";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    # Bootstrap-only VM password. Change this value in this repository before
    # using the VM for anything sensitive.
    hashedPassword = "$6$nixosdev$QyqUycwLZRiiEsmZ4jzHtrAwIZ8EdPikwJnmrFAygYLP9/LO2wGcFGF4UrykL8niiDRN76b8ayhPtTAG/Pj7x1";
  };

  security.sudo.wheelNeedsPassword = true;

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
