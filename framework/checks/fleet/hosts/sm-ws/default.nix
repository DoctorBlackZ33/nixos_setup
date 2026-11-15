# The compositor and portals come from the distribution's packages, so the
# host declares them.
{ ... }:
{
  contract.provides = {
    services.hyprland = true;
    portals.hyprland = true;
    portals.gtk = true;
  };
}
