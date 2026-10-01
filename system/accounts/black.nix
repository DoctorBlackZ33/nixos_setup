{ pkgs, ... }:
{
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
    # Bootstrap-only VM password. Change this value before using the VM
    # for anything sensitive.
    hashedPassword = "$6$nixosdev$QyqUycwLZRiiEsmZ4jzHtrAwIZ8EdPikwJnmrFAygYLP9/LO2wGcFGF4UrykL8niiDRN76b8ayhPtTAG/Pj7x1";
  };
}
