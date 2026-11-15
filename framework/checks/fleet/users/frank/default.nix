# Uses an argument only the config flake can supply (`framework.moduleArgs`).
{ greeting, ... }:
{
  files.".config/demo/greeting".text = greeting;
}
