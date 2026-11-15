# Plain data -> typed value. Everything hand-written that is not a module
# (facts, provides, the inventory, account files) goes through here, so
# defaults apply and unknown fields fail, with the file named in the error.
{ lib }:
let
  declaration = type: { options.value = lib.mkOption { inherit type; }; };
in
{
  # Several definitions of one value; priorities decide between them.
  eval = type: definitions:
    (lib.evalModules {
      modules = [ (declaration type) ] ++ map (value: { inherit value; }) definitions;
    }).config.value;

  # One definition that came from `file`.
  evalFile = type: file: value:
    (lib.evalModules {
      modules = [
        (declaration type)
        {
          _file = file;
          inherit value;
        }
      ];
    }).config.value;
}
