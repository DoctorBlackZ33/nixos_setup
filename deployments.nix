# The inventory: which users run on which host. What a host is (NixOS or not,
# workstation or server, platform) lives in hosts/<host>/facts.nix and selects
# the adapters; nothing here repeats it.
#
#   <name> = {
#     host = "<directory under hosts/>";   # default: <name>
#     users = [ "<directory under users/>" ];   # may be empty
#     homes.<user> = "/custom/home";       # standalone delivery only
#   };
{
  desktop = { users = [ "black" ]; };
  latitude = { users = [ "black" ]; };
  server = { users = [ "black" ]; };
  dev-vm = { users = [ "black" ]; };
}
