{ pkgs, ... }:
{
  users.mutableUsers = false;
  users.users.black = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    hashedPassword = "$6$nixosdev$QyqUycwLZRiiEsmZ4jzHtrAwIZ8EdPikwJnmrFAygYLP9/LO2wGcFGF4UrykL8niiDRN76b8ayhPtTAG/Pj7x1";
  };
}

